import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'store.dart';

/// Local notifications only — no server anywhere.
/// 1. Window alerts: [alertLeadDays] before a hard season window opens.
/// 2. Trip reminders: 7 days before a planned trip.
/// 3. Monthly digest: 9am on the 1st — what opens this month.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Los_Angeles'));
    } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
        const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'poppy', 'Poppy',
          channelDescription: 'Season windows, trip reminders, monthly digest',
          importance: Importance.defaultImportance,
        ),
      );

  Future<void> _schedule(
      int id, DateTime when, String title, String body) async {
    if (when.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Recomputes the whole schedule from current data. Called after any
  /// change to plans/settings and on every launch.
  Future<void> reschedule() async {
    if (!_ready) await init();
    final app = AppState.instance;
    await _plugin.cancelAll();
    var id = 1;

    if (app.alertsOn) {
      final now = DateTime.now();
      final seen = <String>{};
      for (final p in app.allPlaces) {
        final s = p.season;
        if (s == null || !s.hard || app.isDone(p.id)) continue;
        final open = s.nextOpening(now.month);
        if (open == null) continue;
        var year = now.year;
        if (open < now.month || (open == now.month)) year++;
        final opens = DateTime(year, open, 1);
        final fireAt = opens
            .subtract(Duration(days: app.alertLeadDays))
            .copyWith(hour: 9);
        final key = '${p.season!.label}-$open';
        if (seen.contains(key)) continue; // one alert per shared window
        seen.add(key);
        await _schedule(id++, fireAt, 'Window opening: ${p.name}',
            '${s.label}. Opens around ${_monthName(open)} — time to plan.');
        if (id > 40) break; // Android caps pending notifications
      }
    }

    for (final plan in app.plans) {
      final t = app.trip(plan.tripId);
      if (t == null) continue;
      final remind =
          plan.start.subtract(const Duration(days: 7)).copyWith(hour: 9);
      await _schedule(id++, remind, 'Trip in one week',
          '${t.name} — ${_dateRange(plan.start, plan.end)}.');
      await _schedule(
          id++,
          plan.start.copyWith(hour: 7),
          'Trip day: ${t.name}',
          'Poppy has your stops ready. Drive safe.');
    }

    if (app.digestOn) {
      final now = DateTime.now();
      for (var i = 1; i <= 3; i++) {
        final first = DateTime(now.year, now.month + i, 1, 9);
        final m = first.month;
        final opening = app.allPlaces
            .where((p) =>
                p.season != null &&
                !app.isDone(p.id) &&
                p.season!.nextOpening(m == 1 ? 12 : m - 1) == m)
            .map((p) => p.name)
            .take(4)
            .toList();
        if (opening.isEmpty) continue;
        await _schedule(id++, first, '${_monthName(m)} opens up',
            opening.join(' · '));
      }
    }
  }

  String _monthName(int m) => const [
        'January', 'February', 'March', 'April', 'May', 'June', 'July',
        'August', 'September', 'October', 'November', 'December'
      ][m - 1];

  String _dateRange(DateTime a, DateTime b) {
    final mo = _monthName(a.month).substring(0, 3);
    if (a.month == b.month && a.day == b.day) return '$mo ${a.day}';
    if (a.month == b.month) return '$mo ${a.day}–${b.day}';
    return '$mo ${a.day} – ${_monthName(b.month).substring(0, 3)} ${b.day}';
  }
}
