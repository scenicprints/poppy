import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'store.dart';

/// Private repo holding overlay.json — versioned backup + phone-swap restore.
/// Same shape as fuelwise-data. PAT lives in secure storage only.
const String kDataRepo = 'scenicprints/poppy-data';
const String kDataPath = 'overlay.json';

enum SyncStatus { idle, busy, ok, error }

class Backup extends ChangeNotifier {
  Backup._();
  static final Backup instance = Backup._();

  static const _tokenKey = 'poppy.gh_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  bool get connected => _token != null && _token!.isNotEmpty;

  SyncStatus status = SyncStatus.idle;
  DateTime? lastSync;
  String? message;
  Timer? _debounce;

  Future<void> init() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    AppState.instance.addListener(_onChanged);
    notifyListeners();
  }

  void _onChanged() {
    if (!connected) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () => push(silent: true));
  }

  Future<void> connect(String token) async {
    _token = token.trim();
    await _storage.write(key: _tokenKey, value: _token);
    notifyListeners();
    await push();
  }

  Future<void> disconnect() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
    status = SyncStatus.idle;
    notifyListeners();
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
      };

  Future<String?> _currentSha() async {
    final res = await http.get(
      Uri.parse('https://api.github.com/repos/$kDataRepo/contents/$kDataPath'),
      headers: _headers,
    );
    if (res.statusCode != 200) return null;
    return (json.decode(res.body) as Map<String, dynamic>)['sha'] as String?;
  }

  Future<void> push({bool silent = false}) async {
    if (!connected) return;
    status = SyncStatus.busy;
    if (!silent) notifyListeners();
    try {
      final sha = await _currentSha();
      final body = {
        'message': 'poppy backup ${DateTime.now().toIso8601String()}',
        'content': base64Encode(
            utf8.encode(json.encode(AppState.instance.overlayJson()))),
        if (sha != null) 'sha': sha,
      };
      final res = await http.put(
        Uri.parse(
            'https://api.github.com/repos/$kDataRepo/contents/$kDataPath'),
        headers: _headers,
        body: json.encode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        status = SyncStatus.ok;
        lastSync = DateTime.now();
        message = null;
      } else {
        status = SyncStatus.error;
        message = 'GitHub said ${res.statusCode}';
      }
    } catch (e) {
      status = SyncStatus.error;
      message = 'No connection';
    }
    notifyListeners();
  }

  Future<bool> restore() async {
    if (!connected) return false;
    status = SyncStatus.busy;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse(
            'https://api.github.com/repos/$kDataRepo/contents/$kDataPath'),
        headers: {..._headers, 'Accept': 'application/vnd.github.raw+json'},
      );
      if (res.statusCode != 200) {
        status = SyncStatus.error;
        message = 'Nothing to restore (${res.statusCode})';
        notifyListeners();
        return false;
      }
      final app = AppState.instance;
      // Feed the fetched overlay through the normal reader, then persist.
      app.done.clear();
      final j = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      // Reuse private reader via a round-trip: write then reload is overkill;
      // instead apply the public fields directly.
      app.applyOverlay(j);
      status = SyncStatus.ok;
      lastSync = DateTime.now();
      notifyListeners();
      return true;
    } catch (_) {
      status = SyncStatus.error;
      message = 'Restore failed';
      notifyListeners();
      return false;
    }
  }
}
