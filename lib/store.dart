import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Raw URL of the live seed. Editing data/california-trip-planner.md and
/// pushing regenerates assets/seed.json (GitHub Action), and every install
/// picks it up here — no APK release needed for list changes.
const String kSeedUrl =
    'https://raw.githubusercontent.com/scenicprints/poppy/main/assets/seed.json';

/// Home base for drive-time estimates.
const double kHomeLat = 37.639, kHomeLon = -120.997;

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  late Seed seed;
  bool ready = false;

  // ---- overlay: everything the user owns ----
  final Map<String, String> done = {}; // placeId -> yyyy-mm-dd
  final Set<String> hidden = {};
  final List<Place> customPlaces = [];
  final List<Trip> customTrips = [];
  final List<Plan> plans = [];
  final List<Reservation> reservations = [];
  final Map<String, bool> tripStopDone = {}; // "$tripId/$index" -> true
  final Map<String, List<String>> tripExtras = {}; // tripId -> added placeIds

  // settings
  bool alertsOn = true;
  bool digestOn = true;
  int alertLeadDays = 21;
  bool darkMode = false;

  DateTime? lastSeedRefresh;

  // ------------------------------------------------------------------ load
  Future<void> load() async {
    // Newest seed wins: bundled asset vs previously fetched copy.
    final bundled =
        Seed.fromJson(json.decode(await rootBundle.loadString('assets/seed.json'))
            as Map<String, dynamic>);
    Seed? fetched;
    try {
      final f = await _seedFile();
      if (f.existsSync()) {
        fetched = Seed.fromJson(
            json.decode(f.readAsStringSync()) as Map<String, dynamic>);
      }
    } catch (_) {}
    seed = (fetched != null && fetched.version > bundled.version)
        ? fetched
        : bundled;

    try {
      final f = await _overlayFile();
      if (f.existsSync()) {
        _readOverlay(json.decode(f.readAsStringSync()) as Map<String, dynamic>);
      }
    } catch (_) {}

    ready = true;
    notifyListeners();
    // Quietly look for a newer list in the background.
    refreshSeed(silent: true);
  }

  Future<File> _seedFile() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/seed.json');
  Future<File> _overlayFile() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/overlay.json');

  // ---------------------------------------------------------------- seed
  /// Pulls the latest seed from GitHub. Returns true if the list changed.
  Future<bool> refreshSeed({bool silent = false}) async {
    try {
      final res = await http.get(Uri.parse(kSeedUrl)).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return false;
      final fresh =
          Seed.fromJson(json.decode(res.body) as Map<String, dynamic>);
      lastSeedRefresh = DateTime.now();
      if (fresh.version > seed.version) {
        seed = fresh;
        (await _seedFile()).writeAsStringSync(res.body);
        notifyListeners();
        return true;
      }
      if (!silent) notifyListeners();
    } catch (_) {}
    return false;
  }

  // -------------------------------------------------------------- overlay
  void _readOverlay(Map<String, dynamic> j) {
    done
      ..clear()
      ..addAll((j['done'] as Map? ?? {}).cast<String, String>());
    hidden
      ..clear()
      ..addAll((j['hidden'] as List? ?? const []).cast<String>());
    customPlaces
      ..clear()
      ..addAll((j['customPlaces'] as List? ?? const []).map(
          (p) => Place.fromJson(p as Map<String, dynamic>, custom: true)));
    customTrips
      ..clear()
      ..addAll((j['customTrips'] as List? ?? const [])
          .map((t) => Trip.fromJson(t as Map<String, dynamic>, custom: true)));
    plans
      ..clear()
      ..addAll((j['plans'] as List? ?? const [])
          .map((p) => Plan.fromJson(p as Map<String, dynamic>)));
    reservations
      ..clear()
      ..addAll((j['reservations'] as List? ?? const [])
          .map((r) => Reservation.fromJson(r as Map<String, dynamic>)));
    tripStopDone
      ..clear()
      ..addAll((j['tripStopDone'] as Map? ?? {}).cast<String, bool>());
    tripExtras.clear();
    (j['tripExtras'] as Map? ?? {}).forEach((k, v) {
      tripExtras[k as String] = (v as List).cast<String>();
    });
    final s = j['settings'] as Map<String, dynamic>? ?? {};
    alertsOn = s['alertsOn'] as bool? ?? true;
    digestOn = s['digestOn'] as bool? ?? true;
    alertLeadDays = s['alertLeadDays'] as int? ?? 21;
    darkMode = s['darkMode'] as bool? ?? false;
  }

  /// Replace the overlay wholesale (backup restore) and persist it.
  void applyOverlay(Map<String, dynamic> j) {
    _readOverlay(j);
    save();
  }

  Map<String, dynamic> overlayJson() => {
        'done': done,
        'hidden': hidden.toList(),
        'customPlaces': customPlaces.map((p) => p.toJson()).toList(),
        'customTrips': customTrips.map((t) => t.toJson()).toList(),
        'plans': plans.map((p) => p.toJson()).toList(),
        'reservations': reservations.map((r) => r.toJson()).toList(),
        'tripStopDone': tripStopDone,
        'tripExtras': tripExtras,
        'settings': {
          'alertsOn': alertsOn,
          'digestOn': digestOn,
          'alertLeadDays': alertLeadDays,
          'darkMode': darkMode,
        },
      };

  Future<void> save() async {
    try {
      (await _overlayFile())
          .writeAsStringSync(const JsonEncoder.withIndent(' ')
              .convert(overlayJson()));
    } catch (_) {}
    notifyListeners();
  }

  // ------------------------------------------------------------- queries
  List<Place> get allPlaces => [
        ...seed.places.where((p) => !hidden.contains(p.id)),
        ...customPlaces,
      ];

  List<Trip> get allTrips => [...seed.trips, ...customTrips];

  Place? place(String id) {
    for (final p in allPlaces) {
      if (p.id == id) return p;
    }
    return null;
  }

  Trip? trip(String id) {
    for (final t in allTrips) {
      if (t.id == id) return t;
    }
    return null;
  }

  Region? region(String id) {
    for (final r in seed.regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  bool isDone(String id) => done.containsKey(id);

  List<Place> regionPlaces(String regionId) =>
      allPlaces.where((p) => p.region == regionId).toList();

  List<Place> inSeasonNow() {
    final m = DateTime.now().month;
    return allPlaces
        .where((p) => p.season != null && p.season!.inMonth(m))
        .toList();
  }

  /// Hard windows whose current run ends this month or next.
  List<Place> closingSoon() {
    final now = DateTime.now();
    final m = now.month;
    final next = m == 12 ? 1 : m + 1;
    return allPlaces.where((p) {
      final s = p.season;
      if (s == null || !s.hard) return false;
      final end = s.runEnd(m);
      return end == m || end == next;
    }).toList();
  }

  int get doneCount => done.keys.where((id) => place(id) != null).length;

  Plan? get nextPlan {
    final today = DateTime.now();
    final up = plans
        .where((p) => !p.end.isBefore(DateTime(today.year, today.month, today.day)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return up.isEmpty ? null : up.first;
  }

  /// A plan whose window includes today, if any (drives Trip Day mode).
  Plan? get activePlan {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    for (final p in plans) {
      if (!today.isBefore(p.start) && !today.isAfter(p.end)) return p;
    }
    return null;
  }

  // ------------------------------------------------------------ mutations
  void toggleDone(String id) {
    if (done.containsKey(id)) {
      done.remove(id);
    } else {
      done[id] = DateTime.now().toIso8601String().substring(0, 10);
    }
    save();
  }

  void setDoneDate(String id, DateTime d) {
    done[id] = d.toIso8601String().substring(0, 10);
    save();
  }

  void hide(String id) {
    hidden.add(id);
    save();
  }

  void restore(String id) {
    hidden.remove(id);
    save();
  }

  void addCustomPlace(Place p) {
    customPlaces.add(p);
    save();
  }

  void removeCustomPlace(String id) {
    customPlaces.removeWhere((p) => p.id == id);
    done.remove(id);
    save();
  }

  void addCustomTrip(Trip t) {
    customTrips.add(t);
    save();
  }

  void removeCustomTrip(String id) {
    customTrips.removeWhere((t) => t.id == id);
    plans.removeWhere((p) => p.tripId == id);
    save();
  }

  void planTrip(String tripId, DateTime start, DateTime end) {
    plans.removeWhere((p) => p.tripId == tripId);
    plans.add(Plan(tripId: tripId, start: start, end: end));
    save();
  }

  void unplanTrip(String tripId) {
    plans.removeWhere((p) => p.tripId == tripId);
    save();
  }

  /// A trip's stops including any places the user added to it.
  List<TripStop> stopsOf(Trip t) => [
        ...t.stops,
        for (final id in tripExtras[t.id] ?? const <String>[])
          TripStop(text: place(id)?.name ?? id, placeId: id),
      ];

  void addTripExtra(String tripId, String placeId) {
    final list = tripExtras.putIfAbsent(tripId, () => []);
    if (!list.contains(placeId)) list.add(placeId);
    save();
  }

  void removeTripExtra(String tripId, String placeId) {
    tripExtras[tripId]?.remove(placeId);
    save();
  }

  bool tripHasPlace(Trip t, String placeId) =>
      stopsOf(t).any((s) => s.placeId == placeId);

  void toggleStop(String tripId, int index) {
    final key = '$tripId/$index';
    if (tripStopDone[key] == true) {
      tripStopDone.remove(key);
    } else {
      tripStopDone[key] = true;
      // Checking a stop that maps to a place marks the place done too.
      final t = trip(tripId);
      if (t != null) {
        final stops = stopsOf(t);
        if (index < stops.length) {
          final pid = stops[index].placeId;
          if (pid != null && !done.containsKey(pid)) {
            done[pid] = DateTime.now().toIso8601String().substring(0, 10);
          }
        }
      }
    }
    save();
  }

  bool stopDone(String tripId, int index) => tripStopDone['$tripId/$index'] == true;

  int tripProgress(Trip t) {
    var n = 0;
    final total = stopsOf(t).length;
    for (var i = 0; i < total; i++) {
      if (stopDone(t.id, i)) n++;
    }
    return n;
  }
}
