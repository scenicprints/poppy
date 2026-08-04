import 'package:flutter/material.dart';

import 'models.dart';
import 'place_sheet.dart';
import 'store.dart';
import 'theme.dart';
import 'trips_screen.dart' show TripDetailPage;

/// Fixed art direction per region: emoji + tile color.
const Map<String, (String, int)> kRegionArt = {
  'modesto-and-the-central-valley': ('🌾', 0xFF8A6D3B),
  'greater-bay-area': ('🌉', 0xFF31556B),
  'the-eastern-sierra-and-southern-sequoia-kings-canyon': ('⛰️', 0xFF4A6B4F),
  'out-of-state': ('🏜️', 0xFF8C4A2A),
  'lake-tahoe': ('🏔️', 0xFF2F6B74),
  'gold-country-sierra-foothills': ('⛏️', 0xFFA1762C),
  'napa-and-sonoma-wine-country': ('🍇', 0xFF6D3B62),
  'santa-cruz-and-monterey-bay': ('🌊', 0xFF2B7A8C),
  'big-sur-and-the-central-coast': ('🌁', 0xFF3B6D5E),
  'santa-barbara-solvang-and-the-channel-islands': ('🏛️', 0xFFB3701E),
  'los-angeles': ('🎬', 0xFF7C4A8C),
  'orange-county': ('🏄', 0xFFC46A2A),
  'san-diego': ('⚓', 0xFF2A5CB3),
  'palm-springs-and-the-deserts': ('🌵', 0xFFB3552A),
  'northern-california-redwoods-shasta-lassen-mendocino': ('🌲', 0xFF2E5339),
  'statewide-experiences-and-road-trips': ('🛣️', 0xFF5A5A4A),
};

(String, Color) regionArt(String id) {
  final a = kRegionArt[id];
  return a == null ? ('📍', const Color(0xFF5A5A4A)) : (a.$1, Color(a.$2));
}

class RegionsScreen extends StatelessWidget {
  const RegionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Regions', style: serif(context, size: 26)),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final r in app.seed.regions) _tile(context, r),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Region r) {
    final app = AppState.instance;
    final places = app.regionPlaces(r.id);
    final done = places.where((p) => app.isDone(p.id)).length;
    final month = DateTime.now().month;
    final inSeason = places
        .where((p) =>
            p.season != null && p.season!.inMonth(month) && !app.isDone(p.id))
        .length;
    final (em, color) = regionArt(r.id);
    final pct = places.isEmpty ? 0.0 : done / places.length;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RegionHubPage(region: r))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(children: [
              if (inSeason > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('🟢 $inSeason in season',
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              const Spacer(),
              Text(em, style: const TextStyle(fontSize: 20)),
            ]),
            const Spacer(),
            Text(_shortName(r.name),
                maxLines: 2,
                style: serif(context, size: 14.5, color: Colors.white)),
            const SizedBox(height: 3),
            Text('$done/${places.length} done',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.92))),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortName(String n) {
    // Tile-friendly names; the hub shows the full one.
    const cuts = [' / Sierra Foothills'];
    var out = n.split(' (').first;
    for (final c in cuts) {
      out = out.replaceAll(c, '');
    }
    return out;
  }
}

class RegionHubPage extends StatefulWidget {
  final Region region;
  const RegionHubPage({super.key, required this.region});
  @override
  State<RegionHubPage> createState() => _RegionHubPageState();
}

class _RegionHubPageState extends State<RegionHubPage> {
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final r = widget.region;
    final (em, color) = regionArt(r.id);
    final places = app.regionPlaces(r.id);
    final done = places.where((p) => app.isDone(p.id)).length;
    final pct = places.isEmpty ? 0 : (done / places.length * 100).round();
    final month = DateTime.now().month;
    final inSeason = places
        .where((p) =>
            p.season != null && p.season!.inMonth(month) && !app.isDone(p.id))
        .toList();
    final trips = app.allTrips
        .where((t) => t.stops.any((s) =>
            s.placeId != null && app.place(s.placeId!)?.region == r.id))
        .toList();

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                _BackDot(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 10),
                Expanded(
                    child:
                        Text(r.name, style: serif(context, size: 19), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, Colors.black, 0.4)!],
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$em ${r.name}',
                          style: serif(context, size: 21, color: Colors.white)),
                      const SizedBox(height: 5),
                      Text(
                          '${places.length} places · ${inSeason.length} in season right now',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85))),
                    ],
                  ),
                ),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    Text('$pct%',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ]),
                ),
              ]),
            ),
            if (inSeason.isNotEmpty) ...[
              _sect(context, 'In season now'),
              for (final p in inSeason.take(6)) _placeRow(context, p),
            ],
            if (trips.isNotEmpty) ...[
              _sect(context, 'Trips in this region'),
              for (final t in trips.take(4))
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Card(
                    child: ListTile(
                      leading: const Text('🧭', style: TextStyle(fontSize: 20)),
                      title: Text(t.name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.ink)),
                      subtitle: Text(t.tier,
                          style:
                              TextStyle(fontSize: 11.5, color: context.ink2)),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => TripDetailPage(tripId: t.id))),
                    ),
                  ),
                ),
            ],
            _sect(context, 'All places'),
            for (final p in places) _placeRow(context, p),
          ],
        ),
      ),
    );
  }

  Widget _sect(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: P.poppy)),
      );

  Widget _placeRow(BuildContext context, Place p) {
    final app = AppState.instance;
    final month = DateTime.now().month;
    final done = app.isDone(p.id);
    final inSeason = p.season != null && p.season!.inMonth(month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await showPlaceSheet(context, p);
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(children: [
              SizedBox(
                width: 44,
                height: 44,
                child: PlacePhoto(p,
                    height: 44, radius: BorderRadius.circular(11)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: done ? context.ink2 : context.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                        )),
                    if ((p.desc ?? '').isNotEmpty)
                      Text(p.desc!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: context.ink2)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (inSeason && !done)
                const SeasonPill('in season', 'now')
              else if (p.season != null)
                SeasonPill(
                    p.season!.hard ? 'window' : 'seasonal',
                    p.season!.hard ? 'hard' : 'best'),
              const SizedBox(width: 8),
              DoneCircle(
                on: done,
                onTap: () {
                  app.toggleDone(p.id);
                  setState(() {});
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BackDot extends StatelessWidget {
  final VoidCallback onTap;
  const _BackDot({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.card,
            border: Border.all(color: context.line),
          ),
          child: Icon(Icons.arrow_back_ios_new, size: 14, color: context.ink),
        ),
      );
}
