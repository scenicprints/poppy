import 'package:flutter/material.dart';

import 'place_sheet.dart';
import 'store.dart';
import 'theme.dart';
import 'trips_screen.dart' show TripDetailPage;

/// Month-grid calendar: season windows as colored bars across their dates,
/// planned trips as poppy dots, legend below decoding everything.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _WindowEntry {
  final String label;
  final Color color;
  final String tag;
  final int startDay, endDay;
  final String? placeId;
  _WindowEntry(this.label, this.color, this.tag, this.startDay, this.endDay,
      [this.placeId]);
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  static const _palette = [
    Color(0xFFC9660E),
    Color(0xFF4A6B4F),
    Color(0xFF5B4A78),
    Color(0xFF2B7A8C),
    Color(0xFFB3701E),
    Color(0xFF8C2B4A),
    Color(0xFF2A5CB3),
    Color(0xFF6D3B62),
  ];

  List<_WindowEntry> _windows() {
    final app = AppState.instance;
    final m = _month.month;
    final days = DateUtils.getDaysInMonth(_month.year, m);
    final out = <_WindowEntry>[];
    final seenLabels = <String>{};
    // Hard windows first (they matter most), then best-time, dedup by label.
    final seasonal = app.allPlaces
        .where((p) => p.season != null && p.season!.inMonth(m))
        .toList()
      ..sort((a, b) {
        int rank(p) => p.season!.hard ? 0 : 1;
        return rank(a).compareTo(rank(b));
      });
    var ci = 0;
    for (final p in seasonal) {
      final s = p.season!;
      if (seenLabels.contains(s.label)) continue;
      seenLabels.add(s.label);
      final prev = m == 1 ? 12 : m - 1;
      final next = m == 12 ? 1 : m + 1;
      final startsHere = !s.months.contains(prev);
      final endsHere = !s.months.contains(next);
      out.add(_WindowEntry(
        p.name,
        _palette[ci % _palette.length],
        s.label,
        startsHere ? _guessEdge(s.label, start: true) : 1,
        endsHere ? _guessEdge(s.label, start: false, max: days) : days,
        p.id,
      ));
      ci++;
      if (out.length >= 7) break;
    }
    return out;
  }

  /// "late Sept", "mid Oct", "Dec 15" style hints nudge bar edges;
  /// otherwise windows span the whole month.
  int _guessEdge(String label, {required bool start, int max = 31}) {
    final l = label.toLowerCase();
    final dayMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(l);
    if (dayMatch != null) {
      final d = int.parse(dayMatch.group(1)!);
      if (d >= 1 && d <= 31) return d.clamp(1, max);
    }
    if (start) {
      if (l.contains('late')) return (max * 2 / 3).round();
      if (l.contains('mid')) return (max / 2).round();
      return 1;
    } else {
      if (l.contains('early')) return (max / 3).round();
      if (l.contains('mid')) return (max / 2).round();
      return max;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday % 7; // Sun=0
    final now = DateTime.now();
    final windows = _windows();
    final monthPlans = app.plans
        .where((p) =>
            (p.start.year == _month.year && p.start.month == _month.month) ||
            (p.end.year == _month.year && p.end.month == _month.month))
        .toList();

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Calendar', style: serif(context, size: 26)),
              ),
              const Spacer(),
              _navBtn(context, Icons.chevron_left, () {
                setState(() =>
                    _month = DateTime(_month.year, _month.month - 1));
              }),
              Container(
                width: 130,
                alignment: Alignment.center,
                child: Text(
                    '${monthNames[_month.month - 1]} ${_month.year}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.ink)),
              ),
              _navBtn(context, Icons.chevron_right, () {
                setState(() =>
                    _month = DateTime(_month.year, _month.month + 1));
              }),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                        Expanded(
                          child: Center(
                            child: Text(d,
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.ink2)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var week = 0;
                      week * 7 < firstWeekday + days;
                      week++)
                    Row(
                      children: [
                        for (var dow = 0; dow < 7; dow++)
                          Expanded(
                            child: _dayCell(
                              context,
                              week * 7 + dow - firstWeekday + 1,
                              days,
                              now,
                              windows,
                              monthPlans,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final plan in monthPlans)
            _legendRow(
              context,
              leading: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: P.poppy, shape: BoxShape.circle)),
              label: app.trip(plan.tripId)?.name ?? 'Trip',
              bold: true,
              tag:
                  '${plan.start.day}–${plan.end.day}',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TripDetailPage(tripId: plan.tripId))),
            ),
          for (final w in windows)
            _legendRow(
              context,
              leading: Container(
                  width: 22,
                  height: 6,
                  decoration: BoxDecoration(
                      color: w.color,
                      borderRadius: BorderRadius.circular(3))),
              label: w.label,
              tag: w.tag,
              onTap: w.placeId == null
                  ? null
                  : () {
                      final p = AppState.instance.place(w.placeId!);
                      if (p != null) showPlaceSheet(context, p);
                    },
            ),
          if (windows.isEmpty && monthPlans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No special windows this month — everything year-round is fair game.',
                style: TextStyle(fontSize: 13, color: context.ink2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navBtn(BuildContext c, IconData i, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.card,
            border: Border.all(color: c.line),
          ),
          child: Icon(i, size: 17, color: c.ink),
        ),
      );

  Widget _dayCell(BuildContext context, int day, int days, DateTime now,
      List<_WindowEntry> windows, List plans) {
    if (day < 1 || day > days) return const SizedBox(height: 46);
    final isToday = now.year == _month.year &&
        now.month == _month.month &&
        now.day == day;
    final bars = windows
        .where((w) => day >= w.startDay && day <= w.endDay)
        .take(3)
        .toList();
    final hasPlan = plans.any((p) =>
        !DateTime(_month.year, _month.month, day).isBefore(p.start) &&
        !DateTime(_month.year, _month.month, day).isAfter(p.end));
    return SizedBox(
      height: 46,
      child: Column(
        children: [
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: isToday
                ? const BoxDecoration(color: P.poppy, shape: BoxShape.circle)
                : null,
            child: Text('$day',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : context.ink)),
          ),
          const SizedBox(height: 2),
          for (final b in bars)
            Container(
              margin: const EdgeInsets.only(bottom: 1.5),
              height: 3.5,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: b.color, borderRadius: BorderRadius.circular(2)),
            ),
          if (hasPlan)
            Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: P.poppy, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _legendRow(BuildContext context,
      {required Widget leading,
      required String label,
      required String tag,
      bool bold = false,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    color: context.ink)),
          ),
          Text(tag,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.ink2)),
        ]),
      ),
    );
  }
}
