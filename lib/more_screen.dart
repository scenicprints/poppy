import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backup.dart';
import 'models.dart';
import 'notifications.dart';
import 'place_sheet.dart';
import 'regions_screen.dart' show regionArt;
import 'services.dart';
import 'store.dart';
import 'theme.dart';
import 'updater.dart' as updater;

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final closing = app.closingSoon();
    final next = app.nextPlan;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Toolkit', style: serif(context, size: 26)),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _tile(context, '🎟️', 'Reservations',
                  'Things that must be booked, with reminders',
                  () => _push(context, const ReservationsPage())),
              _tile(context, '🚦', 'Conditions',
                  'Passes, fall color, park alerts',
                  () => _push(context, const ConditionsPage())),
              _tile(context, '🌌', 'Stargazing',
                  'Moon phases and the good dark weekends',
                  () => _push(context, const StargazingPage())),
              _tile(context, '🎲', 'Surprise Me',
                  "Can't decide? Poppy picks for you",
                  () => surpriseMe(context)),
              _tile(context, '📊', 'Year Recap', 'Your year so far, wrapped',
                  () => _push(context, const RecapPage())),
              _tile(context, '📍', 'Add a place',
                  'Put your own spot on the list',
                  () => addPlaceDialog(context)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Text('⚙️', style: TextStyle(fontSize: 20)),
              title: Text('Settings',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.ink)),
              subtitle: Text('Updates · backup · alerts · dark mode',
                  style: TextStyle(fontSize: 11.5, color: context.ink2)),
              trailing: Icon(Icons.chevron_right, color: context.ink2),
              onTap: () => _push(context, const SettingsPage()),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('AT A GLANCE',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: P.poppy)),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Text('🌼', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${app.inSeasonNow().length} places in season'
                        '${closing.isNotEmpty ? ' · ${closing.first.name} window closing' : ''}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next == null
                            ? 'No trip planned — try This Weekend on the map'
                            : 'Next trip: ${app.trip(next.tripId)?.name ?? ''} in ${next.start.difference(DateTime.now()).inDays} days',
                        style:
                            TextStyle(fontSize: 11.5, color: context.ink2),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext c, Widget page) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => page));

  Widget _tile(BuildContext context, String em, String title, String sub,
          VoidCallback onTap) =>
      Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(em, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.ink)),
                const SizedBox(height: 3),
                Text(sub,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 10.5, height: 1.35, color: context.ink2)),
              ],
            ),
          ),
        ),
      );
}

// ============================================================ this weekend
Future<void> openWeekendPicker(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WeekendSheet(),
  );
}

class _WeekendSheet extends StatelessWidget {
  const _WeekendSheet();

  @override
  Widget build(BuildContext context) {
    final sat = nextSaturday();
    final sun = sat.add(const Duration(days: 1));
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return Container(
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      child: SafeArea(
        top: false,
        child: FutureBuilder<List<WeekendPick>>(
        future: weekendPicks(),
        builder: (context, snap) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'This weekend · ${mo[sat.month - 1]} ${sat.day}–${sun.day}',
                  style: serif(context, size: 21)),
              const SizedBox(height: 4),
              Text('Ranked by season windows, weather, and drive time.',
                  style: TextStyle(fontSize: 12.5, color: context.ink2)),
              const SizedBox(height: 14),
              if (!snap.hasData)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: P.poppy),
                ))
              else if (snap.data!.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      'Nothing seasonal is calling this weekend — the year-round list is all yours.',
                      style: TextStyle(fontSize: 13, color: context.ink2)),
                )
              else
                for (final pick in snap.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          showPlaceSheet(context, pick.place);
                        },
                        leading: SizedBox(
                          width: 46,
                          height: 46,
                          child: PlacePhoto(pick.place,
                              height: 46,
                              radius: BorderRadius.circular(11)),
                        ),
                        title: Text(pick.place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.ink)),
                        subtitle: Text(
                          [
                            if (pick.wx != null)
                              '${pick.wx!.emoji} ${pick.wx!.hi.round()}°',
                            if (pick.drive != null) pick.drive!,
                            pick.why,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: context.ink2),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
        ),
      ),
    );
  }
}

// ============================================================ reservations
class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});
  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final items = [...app.reservations]
      ..sort((a, b) {
        if (a.bookBy == null) return 1;
        if (b.bookBy == null) return -1;
        return a.bookBy!.compareTo(b.bookBy!);
      });
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.ink,
        title: Text('Reservations', style: serif(context, size: 19)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: P.poppy,
        onPressed: () => _add(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  'Track the things that must be booked ahead — Año Nuevo walks, Pinnacles camping, Hearst Castle tours. Poppy reminds you before the book-by date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5, height: 1.5, color: context.ink2),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final r in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading:
                            const Text('🎟️', style: TextStyle(fontSize: 19)),
                        title: Text(r.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.ink,
                              decoration: r.booked
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                        subtitle: Text(
                          [
                            if (r.note.isNotEmpty) r.note,
                            if (r.bookBy != null)
                              'book by ${r.bookBy!.month}/${r.bookBy!.day}',
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 11.5, color: context.ink2),
                        ),
                        trailing: DoneCircle(
                          on: r.booked,
                          size: 24,
                          onTap: () {
                            r.booked = !r.booked;
                            AppState.instance.save();
                            setState(() {});
                          },
                        ),
                        onLongPress: () {
                          AppState.instance.reservations
                              .removeWhere((x) => x.id == r.id);
                          AppState.instance.save();
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Long-press to delete.',
                      style:
                          TextStyle(fontSize: 11, color: context.ink2)),
                ),
              ],
            ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final titleCtl = TextEditingController();
    final noteCtl = TextEditingController();
    DateTime? bookBy;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Track a reservation'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titleCtl,
                decoration: const InputDecoration(
                    labelText: 'What', hintText: 'Año Nuevo guided walk')),
            TextField(
                controller: noteCtl,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'ReserveCalifornia, opens Nov')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 500)),
                  helpText: 'Book by when?',
                );
                if (d != null) setD(() => bookBy = d);
              },
              child: Text(bookBy == null
                  ? 'Set book-by date'
                  : 'Book by ${bookBy!.month}/${bookBy!.day}/${bookBy!.year}'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtl.text.trim().isEmpty) return;
                AppState.instance.reservations.add(Reservation(
                  id: 'r${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtl.text.trim(),
                  note: noteCtl.text.trim(),
                  bookBy: bookBy,
                ));
                AppState.instance.save();
                Notifier.instance.reschedule();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    setState(() {});
  }
}

// ============================================================ conditions
class ConditionsPage extends StatelessWidget {
  const ConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.ink,
        title: Text('Conditions', style: serif(context, size: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sect(context, 'Mountain passes'),
          _link(context, '🏔️', 'Caltrans road conditions',
              'Tioga, Sonora, every pass — live highway info',
              'https://roads.dot.ca.gov/'),
          _link(context, '🏞️', 'Yosemite current conditions',
              'Tioga Road status straight from the park',
              'https://www.nps.gov/yose/planyourvisit/conditions.htm'),
          _sect(context, 'Seasonal reports'),
          _link(context, '🍂', 'California Fall Color',
              'Live Eastern Sierra color reports — check before Bishop Creek',
              'https://californiafallcolor.com/'),
          _link(context, '🌸', 'Anza-Borrego wildflower report',
              'Bloom status for the desert spring',
              'https://www.parks.ca.gov/?page_id=638'),
          _sect(context, 'Park alerts'),
          _link(context, '⚠️', 'Lassen alerts', 'Closures and advisories',
              'https://www.nps.gov/lavo/planyourvisit/conditions.htm'),
          _link(context, '⚠️', 'Pinnacles alerts', 'Closures and advisories',
              'https://www.nps.gov/pinn/planyourvisit/conditions.htm'),
          _link(context, '⚠️', 'Death Valley alerts',
              'Heat and road status — check every time',
              'https://www.nps.gov/deva/planyourvisit/conditions.htm'),
          _sect(context, 'Booking'),
          _link(context, '🎟️', 'ReserveCalifornia',
              'State park camping + Año Nuevo walks',
              'https://www.reservecalifornia.com/'),
          _link(context, '🏕️', 'Recreation.gov',
              'National park camping (Pinnacles) and permits',
              'https://www.recreation.gov/'),
        ],
      ),
    );
  }

  Widget _sect(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: P.poppy)),
      );

  Widget _link(BuildContext context, String em, String title, String sub,
          String url) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            leading: Text(em, style: const TextStyle(fontSize: 19)),
            title: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.ink)),
            subtitle: Text(sub,
                style: TextStyle(fontSize: 11.5, color: context.ink2)),
            trailing: Icon(Icons.open_in_new, size: 16, color: context.ink2),
            onTap: () => launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication),
          ),
        ),
      );
}

// ============================================================ stargazing
class StargazingPage extends StatelessWidget {
  const StargazingPage({super.key});

  static const _darkParks = [
    ('pinnacles-national-park', 'Pinnacles', 'Gold Tier dark-sky park, ~2.5h'),
    ('lassen-volcanic-national-park', 'Lassen', 'Bortle 1 skies, ~4h'),
    ('joshua-tree-national-park', 'Joshua Tree', 'Dark-sky community (winter)'),
    ('death-valley-national-park', 'Death Valley', 'Huge dark skies (winter)'),
  ];

  @override
  Widget build(BuildContext context) {
    final weekends = darkWeekends().take(4).toList();
    final now = DateTime.now();
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.ink,
        title: Text('Stargazing', style: serif(context, size: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < 5; i++)
                    Builder(builder: (context) {
                      final d = now.add(Duration(days: i * 7));
                      final isNew = moonPhase(d) < 0.06 || moonPhase(d) > 0.94;
                      return Column(children: [
                        Text(moonEmoji(d),
                            style: const TextStyle(fontSize: 19)),
                        const SizedBox(height: 3),
                        Text('${mo[d.month - 1]} ${d.day}',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: isNew
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color:
                                    isNew ? P.poppy : context.ink2)),
                      ]);
                    }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text('BEST DARK WEEKENDS AHEAD',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: P.poppy)),
          ),
          for (var i = 0; i < weekends.length; i++)
            Builder(builder: (context) {
              final w = weekends[i];
              final park = _darkParks[i % _darkParks.length];
              final p = AppState.instance.place(park.$1);
              final fri = w.friday;
              final sun = fri.add(const Duration(days: 2));
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: p == null
                        ? null
                        : () => showPlaceSheet(context, p),
                    leading:
                        const Text('🌌', style: TextStyle(fontSize: 20)),
                    title: Text(
                        '${park.$2} · ${mo[fri.month - 1]} ${fri.day}–${sun.day}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.ink)),
                    subtitle: Text(
                      'New moon ${w.moonOffsetDays == 0 ? 'Friday' : w.moonOffsetDays.abs() <= 1 ? 'this weekend' : '${w.moonOffsetDays.abs()} days off'} · ${park.$3}',
                      style:
                          TextStyle(fontSize: 11.5, color: context.ink2),
                    ),
                  ),
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Milky Way core is highest June–August. Desert parks are winter targets — never summer.',
              style: TextStyle(fontSize: 11.5, color: context.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ surprise me
Future<void> surpriseMe(BuildContext context) async {
  final app = AppState.instance;
  final month = DateTime.now().month;
  final pool = app.allPlaces.where((p) => !app.isDone(p.id)).toList();
  if (pool.isEmpty) return;
  // Weight toward in-season: seasonal-now places appear three extra times.
  final weighted = [
    ...pool,
    ...pool.where((p) => p.season != null && p.season!.inMonth(month)),
    ...pool.where((p) => p.season != null && p.season!.inMonth(month)),
    ...pool.where((p) => p.season != null && p.season!.inMonth(month)),
  ];
  weighted.shuffle();
  final pick = weighted.first;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('🎲 Poppy picks…'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: PlacePhoto(pick,
              height: 110, radius: BorderRadius.circular(14)),
        ),
        const SizedBox(height: 10),
        Text(
          [
            AppState.instance.region(pick.region)?.name ?? '',
            if (pick.season != null && pick.season!.inMonth(month))
              'in season right now',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: context.ink2),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            surpriseMe(context);
          },
          child: const Text('Spin again'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: P.poppy),
          onPressed: () {
            Navigator.pop(context);
            showPlaceSheet(context, pick);
          },
          child: const Text('Tell me more'),
        ),
      ],
    ),
  );
}

// ============================================================ add place
Future<void> addPlaceDialog(BuildContext context) async {
  final app = AppState.instance;
  final nameCtl = TextEditingController();
  String regionId = app.seed.regions.first.id;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setD) => AlertDialog(
        title: const Text('Add a place'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtl,
            decoration: const InputDecoration(
                labelText: 'Name', hintText: "e.g. Grandma's favorite diner"),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: regionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Region'),
            items: [
              for (final r in app.seed.regions)
                DropdownMenuItem(
                    value: r.id,
                    child: Text(r.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setD(() => regionId = v ?? regionId),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtl.text.trim();
              if (name.isEmpty) return;
              app.addCustomPlace(Place(
                id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                region: regionId,
                custom: true,
              ));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$name" added to your list')));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

// ============================================================ recap
class RecapPage extends StatefulWidget {
  const RecapPage({super.key});
  @override
  State<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends State<RecapPage> {
  final _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final year = DateTime.now().year;
    final thisYear = app.done.entries
        .where((e) => e.value.startsWith('$year'))
        .map((e) => app.place(e.key))
        .whereType<Place>()
        .toList();
    final regionsTouched =
        thisYear.map((p) => p.region).toSet().length;
    var miles = 0.0;
    final monthCounts = List.filled(12, 0);
    for (final e in app.done.entries) {
      if (!e.value.startsWith('$year')) continue;
      final p = app.place(e.key);
      if (p?.ll != null) {
        miles += milesBetween(kHomeLat, kHomeLon, p!.ll![0], p.ll![1]) * 2;
      }
      monthCounts[DateTime.parse(e.value).month - 1]++;
    }
    var bestMonth = 0;
    for (var i = 0; i < 12; i++) {
      if (monthCounts[i] > monthCounts[bestMonth]) bestMonth = i;
    }
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    final tripsDone = app.allTrips
        .where((t) =>
            t.stops.isNotEmpty && app.tripProgress(t) == t.stops.length)
        .length;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.ink,
        title: Text('$year so far', style: serif(context, size: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              color: context.bg,
              child: Column(children: [
                Row(children: [
                  _stat(context, '${thisYear.length}', 'places this year'),
                  const SizedBox(width: 10),
                  _stat(context, '$regionsTouched/15', 'regions touched'),
                  const SizedBox(width: 10),
                  _stat(context, '${miles.round()}', 'est. miles'),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _stat(
                      context,
                      thisYear.isEmpty
                          ? '—'
                          : monthNames[bestMonth].substring(0, 3),
                      'biggest month'),
                  const SizedBox(width: 10),
                  _stat(context, '$tripsDone', 'trips finished'),
                  const SizedBox(width: 10),
                  _stat(context, '${app.doneCount}', 'all-time done'),
                ]),
                const SizedBox(height: 16),
                for (final r in app.seed.regions)
                  Builder(builder: (context) {
                    final places = app.regionPlaces(r.id);
                    if (places.isEmpty) return const SizedBox.shrink();
                    final done =
                        places.where((p) => app.isDone(p.id)).length;
                    final (em, color) = regionArt(r.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 132,
                          child: Text('$em ${r.name.split(' (').first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: context.ink)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: places.isEmpty
                                  ? 0
                                  : done / places.length,
                              minHeight: 7,
                              backgroundColor: context.line,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 46,
                          child: Text('$done/${places.length}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.ink2)),
                        ),
                      ]),
                    );
                  }),
                const SizedBox(height: 6),
                Text('Poppy · my California year',
                    style:
                        TextStyle(fontSize: 10, color: context.ink2)),
                const SizedBox(height: 6),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: P.poppy),
            onPressed: _share,
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Share recap card'),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String big, String label) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(big, style: serif(context, size: 21, color: P.poppy)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: context.ink2)),
            ]),
          ),
        ),
      );

  Future<void> _share() async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/poppy-recap.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)],
          text: 'My California year so far 🌼');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not render the card — try again')));
      }
    }
  }
}

// ============================================================ settings
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    updater.currentVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final backup = Backup.instance;
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.ink,
        title: Text('Settings', style: serif(context, size: 19)),
      ),
      body: ListView(
        children: [
          _row(
            context,
            '⟳',
            'Check for updates',
            'Poppy v$_version · installs in-app from GitHub',
            onTap: () => updater.manualCheck(context),
          ),
          _row(
            context,
            '📄',
            'Refresh the place list',
            app.lastSeedRefresh == null
                ? 'Pulls the latest list from GitHub'
                : 'List v${app.seed.version} · checked recently',
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(const SnackBar(
                  content: Text('Checking for list changes…')));
              final changed = await app.refreshSeed();
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(SnackBar(
                  content: Text(changed
                      ? 'List updated — new places are in'
                      : 'List is already current')));
              setState(() {});
            },
          ),
          ListenableBuilder(
            listenable: backup,
            builder: (context, _) => _row(
              context,
              '☁️',
              backup.connected ? 'Backup: on' : 'Backup: off',
              backup.connected
                  ? (backup.status == SyncStatus.error
                      ? backup.message ?? 'Error'
                      : 'Private GitHub repo · auto after every change')
                  : 'Connect a GitHub token to survive phone swaps',
              onTap: () => _backupSheet(context),
            ),
          ),
          _toggleRow(context, '🔔', 'Window alerts',
              '${app.alertLeadDays} days before a hard window opens',
              app.alertsOn, (v) {
            app.alertsOn = v;
            app.save();
            Notifier.instance.reschedule();
            setState(() {});
          }),
          _toggleRow(context, '📰', 'Monthly digest',
              "1st of the month: what's opening", app.digestOn, (v) {
            app.digestOn = v;
            app.save();
            Notifier.instance.reschedule();
            setState(() {});
          }),
          _toggleRow(context, '🌙', 'Dark mode', 'Poster art, night edition',
              app.darkMode, (v) {
            app.darkMode = v;
            app.save();
          }),
          _row(
            context,
            '🗂️',
            'Hidden places',
            '${app.hidden.length} removed from your list',
            onTap: app.hidden.isEmpty ? null : () => _hiddenSheet(context),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Poppy checks for app updates on launch and installs them in-app. '
              'The place list itself updates separately — edit the master doc, push, done.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.5, color: context.ink2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String em, String title, String sub,
          {VoidCallback? onTap}) =>
      ListTile(
        leading: Text(em, style: const TextStyle(fontSize: 19)),
        title: Text(title,
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: context.ink)),
        subtitle: Text(sub,
            style: TextStyle(fontSize: 11.5, color: context.ink2)),
        trailing: onTap == null
            ? null
            : Icon(Icons.chevron_right, color: context.ink2),
        onTap: onTap,
      );

  Widget _toggleRow(BuildContext context, String em, String title, String sub,
          bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        secondary: Text(em, style: const TextStyle(fontSize: 19)),
        title: Text(title,
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: context.ink)),
        subtitle: Text(sub,
            style: TextStyle(fontSize: 11.5, color: context.ink2)),
        value: value,
        activeColor: P.doneGreen,
        onChanged: onChanged,
      );

  Future<void> _backupSheet(BuildContext context) async {
    final backup = Backup.instance;
    final ctl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(backup.connected ? 'Backup' : 'Connect backup'),
        content: backup.connected
            ? const Text(
                'Backups push automatically after every change. You can restore onto a new phone, push now, or disconnect.')
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Paste a GitHub token with access to the private poppy-data repo. It stays in secure storage on this phone.',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                TextField(
                  controller: ctl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'GitHub token', hintText: 'ghp_…'),
                ),
              ]),
        actions: [
          if (backup.connected) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final ok = await backup.restore();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? 'Restored from backup'
                          : 'Restore failed')));
                }
                setState(() {});
              },
              child: const Text('Restore'),
            ),
            TextButton(
              onPressed: () {
                backup.disconnect();
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Disconnect'),
            ),
            FilledButton(
              onPressed: () {
                backup.push();
                Navigator.pop(context);
              },
              child: const Text('Push now'),
            ),
          ] else ...[
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (ctl.text.trim().isEmpty) return;
                backup.connect(ctl.text);
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Connect'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _hiddenSheet(BuildContext context) async {
    final app = AppState.instance;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bg,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => SafeArea(
          top: false,
          child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hidden places', style: serif(context, size: 18)),
            const SizedBox(height: 8),
            for (final id in app.hidden.toList())
              Builder(builder: (context) {
                Place? p;
                for (final sp in app.seed.places) {
                  if (sp.id == id) p = sp;
                }
                if (p == null) return const SizedBox.shrink();
                return ListTile(
                  dense: true,
                  title:
                      Text(p.name, style: TextStyle(color: context.ink)),
                  trailing: TextButton(
                    onPressed: () {
                      app.restore(id);
                      setD(() {});
                      setState(() {});
                    },
                    child: const Text('Restore'),
                  ),
                );
              }),
          ],
          ),
        ),
      ),
    );
  }
}
