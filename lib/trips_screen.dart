import 'package:flutter/material.dart';

import 'models.dart';
import 'notifications.dart';
import 'place_sheet.dart';
import 'store.dart';
import 'theme.dart';

String _fmtRange(DateTime a, DateTime b) {
  const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  if (a.month == b.month && a.day == b.day) return '${mo[a.month - 1]} ${a.day}';
  if (a.month == b.month) return '${mo[a.month - 1]} ${a.day}–${b.day}';
  return '${mo[a.month - 1]} ${a.day} – ${mo[b.month - 1]} ${b.day}';
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final trips = app.allTrips.where((t) {
      switch (_filter) {
        case 'Quick':
          return t.tier.toLowerCase().contains('quick');
        case 'Day':
          return t.tier.toLowerCase().contains('day trip');
        case 'Weekend':
          return t.tier.toLowerCase().contains('weekend');
        case 'Mine':
          return t.custom;
        default:
          return true;
      }
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Row(children: [
              Text('Trips', style: serif(context, size: 26)),
              const Spacer(),
              Text('${app.allTrips.length} total',
                  style: TextStyle(fontSize: 12, color: context.ink2)),
            ]),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              children: [
                for (final f in ['All', 'Quick', 'Day', 'Weekend', 'Mine'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 12.5)),
                      selected: _filter == f,
                      selectedColor: P.pine,
                      labelStyle: TextStyle(
                          color: _filter == f ? Colors.white : context.ink),
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              children: [
                for (final t in trips) _tripCard(context, t),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TripBuilderPage()));
                    setState(() {});
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Build my own trip'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(BuildContext context, Trip t) {
    final app = AppState.instance;
    final prog = app.tripProgress(t);
    Plan? plan;
    for (final p in app.plans) {
      if (p.tripId == t.id) plan = p;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TripDetailPage(tripId: t.id)));
            setState(() {});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(t.name, style: serif(context, size: 16))),
                      if (plan != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: P.gold,
                              borderRadius: BorderRadius.circular(7)),
                          child: Text(_fmtRange(plan.start, plan.end),
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4D3306))),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                        [t.tier, if (t.season != null) t.season!]
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11.5, color: context.ink2)),
                    const SizedBox(height: 10),
                    Row(children: [
                      for (var i = 0; i < t.stops.length; i++) ...[
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: app.stopDone(t.id, i)
                                ? P.doneGreen
                                : P.pine.withOpacity(0.75),
                          ),
                        ),
                        if (i < t.stops.length - 1)
                          Expanded(
                              child: Container(
                                  height: 2, color: context.line)),
                      ],
                    ]),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: t.stops.isEmpty ? 0 : prog / t.stops.length,
                minHeight: 5,
                backgroundColor: context.line,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(P.doneGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ trip detail
class TripDetailPage extends StatefulWidget {
  final String tripId;
  const TripDetailPage({super.key, required this.tripId});
  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final t = app.trip(widget.tripId);
    if (t == null) return const Scaffold(body: SizedBox());
    Plan? plan;
    for (final p in app.plans) {
      if (p.tripId == t.id) plan = p;
    }
    // Weekend trips read as two days; everything else one.
    final twoDays = t.tier.toLowerCase().contains('weekend');
    final splitAt = twoDays ? (t.stops.length / 2).ceil() : t.stops.length;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.card,
                        border: Border.all(color: context.line)),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 14, color: context.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(t.name,
                        style: serif(context, size: 18),
                        maxLines: 2)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                SeasonPill(t.tier, 'best'),
                if (t.season != null) SeasonPill(t.season!, 'hard'),
                if (plan != null)
                  SeasonPill(_fmtRange(plan.start, plan.end), 'now'),
              ]),
            ),
            for (var day = 0; day < (twoDays ? 2 : 1); day++) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                child: Text('DAY ${day + 1}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: P.pine)),
              ),
              for (var i = day == 0 ? 0 : splitAt;
                  i < (day == 0 ? splitAt : t.stops.length);
                  i++)
                _stopRow(context, t, i),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
              child: Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: P.poppy),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => TripDayPage(tripId: t.id))),
                    child: const Text('▶ Trip Day view'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _plan(context, t, plan),
                    child: Text(plan == null ? 'Plan this' : 'Reschedule'),
                  ),
                ),
              ]),
            ),
            if (plan != null)
              Center(
                child: TextButton(
                  onPressed: () {
                    app.unplanTrip(t.id);
                    Notifier.instance.reschedule();
                    setState(() {});
                  },
                  child: const Text('Remove from calendar',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFB3520A))),
                ),
              ),
            if (t.custom)
              Center(
                child: TextButton(
                  onPressed: () {
                    app.removeCustomTrip(t.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Delete this trip',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFB3520A))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stopRow(BuildContext context, Trip t, int i) {
    final app = AppState.instance;
    final stop = t.stops[i];
    final done = app.stopDone(t.id, i);
    final place = stop.placeId == null ? null : app.place(stop.placeId!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: place == null
              ? null
              : () async {
                  await showPlaceSheet(context, place);
                  setState(() {});
                },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: done ? P.doneGreen : P.pine,
                    shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(stop.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: done ? context.ink2 : context.ink,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                    )),
              ),
              DoneCircle(
                on: done,
                size: 24,
                onTap: () {
                  app.toggleStop(t.id, i);
                  setState(() {});
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _plan(BuildContext context, Trip t, Plan? existing) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 400)),
      initialDateRange: existing == null
          ? null
          : DateTimeRange(start: existing.start, end: existing.end),
      helpText: 'When are you going?',
    );
    if (range != null) {
      AppState.instance.planTrip(t.id, range.start, range.end);
      Notifier.instance.reschedule();
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'On the calendar: ${_fmtRange(range.start, range.end)} · reminder set')));
      }
    }
  }
}

// ============================================================ trip day mode
class TripDayPage extends StatefulWidget {
  final String tripId;
  const TripDayPage({super.key, required this.tripId});
  @override
  State<TripDayPage> createState() => _TripDayPageState();
}

class _TripDayPageState extends State<TripDayPage> {
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final t = app.trip(widget.tripId);
    if (t == null) return const Scaffold(body: SizedBox());
    final doneCount = app.tripProgress(t);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.card,
                        border: Border.all(color: context.line)),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 14, color: context.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Trip Day', style: serif(context, size: 19)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                    colors: [Color(0xFFA44A08), P.poppy]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      style: serif(context, size: 18, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                      '$doneCount of ${t.stops.length} stops done · check them off as you go',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < t.stops.length; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 13),
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: app.stopDone(t.id, i)
                                ? P.doneGreen
                                : P.poppy,
                            shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(t.stops[i].text,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: app.stopDone(t.id, i)
                                    ? context.ink2
                                    : context.ink)),
                      ),
                      DoneCircle(
                        on: app.stopDone(t.id, i),
                        size: 30,
                        onTap: () {
                          app.toggleStop(t.id, i);
                          setState(() {});
                        },
                      ),
                    ]),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Text(
                'Checking a stop that matches a list place marks it done with today\'s date automatically.',
                style: TextStyle(fontSize: 11.5, color: context.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ trip builder
class TripBuilderPage extends StatefulWidget {
  const TripBuilderPage({super.key});
  @override
  State<TripBuilderPage> createState() => _TripBuilderPageState();
}

class _TripBuilderPageState extends State<TripBuilderPage> {
  final _nameCtl = TextEditingController();
  final _searchCtl = TextEditingController();
  final List<Place> _picked = [];
  List<Place> _hits = const [];
  String _tier = 'Day trip';

  void _search(String v) {
    final q = v.trim().toLowerCase();
    setState(() {
      _hits = q.isEmpty
          ? const []
          : AppState.instance.allPlaces
              .where((p) =>
                  p.name.toLowerCase().contains(q) &&
                  !_picked.any((x) => x.id == p.id))
              .take(5)
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.ink,
        title: Text('Build a trip', style: serif(context, size: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtl,
            style: TextStyle(color: context.ink),
            decoration: const InputDecoration(
              labelText: 'Trip name',
              hintText: 'e.g. Coast + missions weekend',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final t in ['Quick trip', 'Day trip', 'Weekend'])
              ChoiceChip(
                label: Text(t, style: const TextStyle(fontSize: 12.5)),
                selected: _tier == t,
                selectedColor: P.pine,
                labelStyle: TextStyle(
                    color: _tier == t ? Colors.white : context.ink),
                onSelected: (_) => setState(() => _tier = t),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtl,
            onChanged: _search,
            style: TextStyle(color: context.ink),
            decoration: const InputDecoration(
              labelText: 'Add stops',
              hintText: 'Search places…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          for (final h in _hits)
            ListTile(
              dense: true,
              title: Text(h.name, style: TextStyle(color: context.ink)),
              trailing: const Icon(Icons.add, size: 18),
              onTap: () {
                setState(() {
                  _picked.add(h);
                  _searchCtl.clear();
                  _hits = const [];
                });
              },
            ),
          const SizedBox(height: 10),
          for (var i = 0; i < _picked.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: context.ink)),
                title:
                    Text(_picked[i].name, style: TextStyle(color: context.ink)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (i > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 17),
                      onPressed: () => setState(() {
                        final p = _picked.removeAt(i);
                        _picked.insert(i - 1, p);
                      }),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 17),
                    onPressed: () => setState(() => _picked.removeAt(i)),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: P.poppy),
            onPressed: _picked.isEmpty
                ? null
                : () {
                    final name = _nameCtl.text.trim().isEmpty
                        ? 'My trip'
                        : _nameCtl.text.trim();
                    final id =
                        'custom-${DateTime.now().millisecondsSinceEpoch}';
                    AppState.instance.addCustomTrip(Trip(
                      id: id,
                      name: name,
                      tier: _tier,
                      custom: true,
                      stops: [
                        for (final p in _picked)
                          TripStop(text: p.name, placeId: p.id)
                      ],
                    ));
                    Navigator.pop(context);
                  },
            child: const Text('Save trip'),
          ),
        ],
      ),
    );
  }
}
