import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'models.dart';
import 'store.dart';

// ============================================================ weather
/// Open-Meteo — free, no key. Daily highs + weather code.
class DayForecast {
  final DateTime date;
  final double hi;
  final int code;
  DayForecast(this.date, this.hi, this.code);

  String get emoji {
    if (code == 0) return '☀️';
    if (code <= 2) return '🌤️';
    if (code == 3) return '☁️';
    if (code >= 51 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '❄️';
    if (code >= 80 && code <= 82) return '🌦️';
    if (code >= 95) return '⛈️';
    return '🌫️';
  }
}

final Map<String, List<DayForecast>> _wxCache = {};

Future<List<DayForecast>?> forecast(double lat, double lon) async {
  final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
  if (_wxCache.containsKey(key)) return _wxCache[key];
  try {
    final res = await http
        .get(Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
            '&daily=temperature_2m_max,weather_code'
            '&temperature_unit=fahrenheit&timezone=America%2FLos_Angeles'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = json.decode(res.body) as Map<String, dynamic>;
    final daily = j['daily'] as Map<String, dynamic>;
    final dates = (daily['time'] as List).cast<String>();
    final his = (daily['temperature_2m_max'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final codes =
        (daily['weather_code'] as List).map((e) => (e as num).toInt()).toList();
    final out = <DayForecast>[];
    for (var i = 0; i < dates.length; i++) {
      out.add(DayForecast(DateTime.parse(dates[i]), his[i], codes[i]));
    }
    _wxCache[key] = out;
    return out;
  } catch (_) {
    return null;
  }
}

// ============================================================ distance
double _deg2rad(double d) => d * math.pi / 180;

double milesBetween(double lat1, double lon1, double lat2, double lon2) {
  const r = 3958.8;
  final dLat = _deg2rad(lat2 - lat1), dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Rough drive-time from home: crow-flies miles / 48 mph average,
/// padded 15% for real roads.
String? driveTimeFromHome(Place p) {
  final ll = p.ll;
  if (ll == null) return null;
  final mi = milesBetween(kHomeLat, kHomeLon, ll[0], ll[1]) * 1.15;
  final hours = mi / 48;
  if (hours < 0.75) return '${(hours * 60).round()} min';
  final h = hours.floor();
  final m = ((hours - h) * 60 / 5).round() * 5;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

// ============================================================ moon
/// Phase 0..1 (0 = new). Standard synodic approximation from a known epoch.
double moonPhase(DateTime d) {
  final known = DateTime.utc(2000, 1, 6, 18, 14); // new moon epoch
  final days = d.toUtc().difference(known).inMinutes / 1440.0;
  const synodic = 29.53058867;
  final phase = (days % synodic) / synodic;
  return phase < 0 ? phase + 1 : phase;
}

String moonEmoji(DateTime d) {
  final p = moonPhase(d);
  const icons = ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'];
  return icons[((p * 8).round()) % 8];
}

/// Upcoming new moons within [days] of now.
List<DateTime> upcomingNewMoons({int days = 120}) {
  final out = <DateTime>[];
  final now = DateTime.now();
  var d = now;
  double? prev;
  for (var i = 0; i < days; i++) {
    final p = moonPhase(d);
    if (prev != null && prev > 0.9 && p < 0.1) out.add(d);
    prev = p;
    d = d.add(const Duration(days: 1));
  }
  return out;
}

class DarkWeekend {
  final DateTime friday;
  final DateTime newMoon;
  DarkWeekend(this.friday, this.newMoon);
  int get moonOffsetDays => newMoon.difference(friday).inDays;
}

/// Fri–Sun weekends within 4 days of an upcoming new moon.
List<DarkWeekend> darkWeekends() {
  final out = <DarkWeekend>[];
  for (final nm in upcomingNewMoons()) {
    // find the Friday nearest this new moon
    var fri = nm;
    while (fri.weekday != DateTime.friday) {
      fri = fri.subtract(const Duration(days: 1));
    }
    for (final cand in [fri, fri.add(const Duration(days: 7))]) {
      final gap = (nm.difference(cand).inDays).abs();
      if (gap <= 4 && cand.isAfter(DateTime.now())) {
        out.add(DarkWeekend(cand, nm));
      }
    }
  }
  out.sort((a, b) => a.friday.compareTo(b.friday));
  return out;
}

// ============================================================ weekend picker
class WeekendPick {
  final Place place;
  final String why;
  final String? drive;
  DayForecast? wx;
  WeekendPick(this.place, this.why, this.drive);
}

/// Next Saturday (or today if it's the weekend).
DateTime nextSaturday() {
  var d = DateTime.now();
  while (d.weekday != DateTime.saturday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}

Future<List<WeekendPick>> weekendPicks() async {
  final app = AppState.instance;
  final sat = nextSaturday();
  final m = sat.month;
  final picks = <WeekendPick>[];

  final candidates = app.allPlaces.where((p) =>
      !app.isDone(p.id) && p.season != null && p.season!.inMonth(m) && p.ll != null);

  final scored = candidates.toList()
    ..sort((a, b) {
      int score(Place p) {
        var s = 0;
        if (p.season!.hard) s += 4;
        final end = p.season!.runEnd(m);
        if (end == m) s += 3; // window closing — urgency
        if (p.pin != null) s += 1;
        return s;
      }

      return score(b).compareTo(score(a));
    });

  for (final p in scored.take(6)) {
    final s = p.season!;
    final end = s.runEnd(m);
    final why = end == m
        ? 'Window closes this month'
        : s.hard
            ? 'In its hard window now'
            : 'At its best right now';
    picks.add(WeekendPick(p, why, driveTimeFromHome(p)));
  }

  // attach Saturday weather to the top few
  for (final pick in picks.take(4)) {
    final fc = await forecast(pick.place.ll![0], pick.place.ll![1]);
    if (fc != null) {
      for (final day in fc) {
        if (day.date.year == sat.year &&
            day.date.month == sat.month &&
            day.date.day == sat.day) {
          pick.wx = day;
          break;
        }
      }
    }
  }
  return picks.take(4).toList();
}
