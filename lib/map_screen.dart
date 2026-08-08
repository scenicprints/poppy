import 'package:flutter/material.dart';

import 'models.dart';
import 'more_screen.dart' show openWeekendPicker, RecapPage;
import 'place_sheet.dart';
import 'store.dart';
import 'theme.dart';

/// The poster map. Everything — the state border, the home star, every pin —
/// is projected from real lat/lon, so geography is correct by construction.
const double kMapW = 300, kMapH = 336;

// Equirectangular projection fitted to California:
// lat 32.4–42.1, lon -124.5 eastward, x squeezed by cos(mid-latitude).
const double _latMax = 42.1, _lonMin = -124.5;
const double _kY = 34.0; // kMapH / lat span
const double _kX = 27.05; // _kY * cos(~37.3°)

Offset projectLL(double lat, double lon) =>
    Offset((lon - _lonMin) * _kX, (_latMax - lat) * _kY);

Offset? pinPos(Place p) {
  Offset? o;
  if (p.ll != null) {
    o = projectLL(p.ll![0], p.ll![1]);
  } else if (p.pin != null) {
    o = Offset(p.pin![0], p.pin![1]);
  }
  if (o == null) return null;
  // Out-of-state places (Grand Canyon leg) fall off the California canvas —
  // they keep weather and drive times but don't draw a pin.
  if (o.dx < 0 || o.dx > kMapW || o.dy < 0 || o.dy > kMapH) return null;
  return o;
}

/// California border as real coordinates, clockwise from the Oregon coast.
const List<double> _border = [
  42.00, -124.21, // Oregon line meets the Pacific
  41.74, -124.18, 41.06, -124.14, 40.44, -124.40, // Cape Mendocino
  39.75, -123.83, 38.95, -123.74, 38.31, -123.06, // Point Arena, Bodega
  37.81, -122.47, 37.60, -122.50, 37.11, -122.33, // Golden Gate, Año Nuevo
  36.95, -122.03, 36.80, -121.79, 36.60, -121.90, // Monterey Bay
  36.24, -121.81, 35.66, -121.28, 35.37, -120.86, // Big Sur, Morro
  35.15, -120.65, 34.45, -120.47, 34.41, -119.69, // Conception, Santa Barbara
  34.03, -118.85, 33.77, -118.42, 33.60, -117.90, // Malibu, Palos Verdes
  33.38, -117.59, 32.53, -117.12, // to the Mexico border
  32.72, -114.72, // east along the border to the Colorado River
  33.40, -114.73, 34.00, -114.44, 34.30, -114.14, // river wiggles north
  35.00, -114.63, // Needles corner
  39.00, -120.00, // the long Nevada diagonal to Tahoe
  42.00, -120.00, // due north, then the top edge closes it
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  final _searchCtl = TextEditingController();
  List<Place> _hits = const [];

  @override
  void dispose() {
    _pulse.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _search(String v) {
    final app = AppState.instance;
    final q = v.trim().toLowerCase();
    setState(() {
      _hits = q.isEmpty
          ? const []
          : app.allPlaces
              .where((p) => p.name.toLowerCase().contains(q))
              .take(6)
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final closing = app.closingSoon();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment(-0.3, -0.3),
                          colors: [Color(0xFFFF8A3D), P.poppy],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Poppy', style: serif(context, size: 26)),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RecapPage())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.card,
                          border: Border.all(color: context.line),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                              text: '${app.doneCount}',
                              style: const TextStyle(
                                  color: P.poppy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5)),
                          TextSpan(
                              text: '/${app.allPlaces.length}',
                              style: TextStyle(
                                  color: context.ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5)),
                        ])),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.card,
                    border: Border.all(color: context.line),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(children: [
                    Icon(Icons.search, size: 18, color: context.ink2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtl,
                        onChanged: _search,
                        decoration: InputDecoration(
                          hintText:
                              'Search ${app.allPlaces.length} places…',
                          hintStyle:
                              TextStyle(color: context.ink2, fontSize: 13.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style:
                            TextStyle(color: context.ink, fontSize: 13.5),
                      ),
                    ),
                  ]),
                ),
                if (closing.isNotEmpty && _hits.isEmpty) ...[
                  const SizedBox(height: 8),
                  _ClosingTicker(place: closing.first),
                ],
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, cons) {
              final mapSize = Size(cons.maxWidth, cons.maxHeight);
              return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    maxScale: 6,
                    child: GestureDetector(
                      onTapUp: (d) => _onMapTap(d.localPosition, mapSize),
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => CustomPaint(
                          painter: PosterMapPainter(
                            places: app.allPlaces,
                            doneIds: app.done.keys.toSet(),
                            month: DateTime.now().month,
                            pulseT: _pulse.value,
                            dark: context.isDark,
                          ),
                          size: mapSize,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hits.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 14,
                    right: 14,
                    child: Card(
                      child: Column(
                        children: [
                          for (final p in _hits)
                            ListTile(
                              dense: true,
                              title: Text(p.name,
                                  style: TextStyle(
                                      color: context.ink,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  app.region(p.region)?.name ?? '',
                                  style: TextStyle(
                                      color: context.ink2, fontSize: 11)),
                              trailing: app.isDone(p.id)
                                  ? const Icon(Icons.check_circle,
                                      color: P.doneGreen, size: 18)
                                  : null,
                              onTap: () {
                                _searchCtl.clear();
                                _search('');
                                showPlaceSheet(context, p);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.card.withOpacity(0.92),
                      border: Border.all(color: context.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legend(context, const Color(0xFF8F8F80), 'not done'),
                        _legend(context, P.doneGreen, 'done'),
                        _legend(context, P.poppy, 'in season'),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: P.poppy,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        textStyle: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      onPressed: () => openWeekendPicker(context),
                      icon: const Text('🗺️'),
                      label: const Text('This Weekend'),
                    ),
                  ),
                ),
              ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext c, Color color, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10, color: c.ink2)),
        ]),
      );

  void _onMapTap(Offset pos, Size size) {
    final scale = mapFitScale(size);
    final off = mapFitOffset(size, scale);
    Place? best;
    double bestD = 18;
    for (final p in AppState.instance.allPlaces) {
      final pp = pinPos(p);
      if (pp == null) continue;
      final d = (Offset(off.dx + pp.dx * scale, off.dy + pp.dy * scale) - pos)
          .distance;
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    if (best != null) showPlaceSheet(context, best);
  }
}

double mapFitScale(Size s) {
  final sx = s.width / kMapW, sy = s.height / kMapH;
  return sx < sy ? sx : sy;
}

Offset mapFitOffset(Size s, double scale) =>
    Offset((s.width - kMapW * scale) / 2, (s.height - kMapH * scale) / 2);

class _ClosingTicker extends StatelessWidget {
  final Place place;
  const _ClosingTicker({required this.place});

  @override
  Widget build(BuildContext context) {
    final end = place.season!.runEnd(DateTime.now().month);
    final label = end == null
        ? place.season!.label
        : '${place.name} — window closes end of ${const [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
            'Oct', 'Nov', 'Dec'
          ][end - 1]}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showPlaceSheet(context, place),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFA44A08), Color(0xFFC9660E)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Text('⏳', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFFFE8D4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const Text('›',
              style: TextStyle(color: Color(0xFFFFE8D4), fontSize: 14)),
        ]),
      ),
    );
  }
}

/// National-park-poster California, drawn from real geography.
class PosterMapPainter extends CustomPainter {
  final List<Place> places;
  final Set<String> doneIds;
  final int month;
  final double pulseT;
  final bool dark;
  final String? highlightId; // focused place: glow ring + label
  final List<String>? routeIds; // ordered stop placeIds: polyline + numbers
  final Set<String>? emphasizeIds; // e.g. a region's places: kept vivid
  final bool dimOthers; // fade pins that aren't part of the focus

  PosterMapPainter({
    required this.places,
    required this.doneIds,
    required this.month,
    required this.pulseT,
    required this.dark,
    this.highlightId,
    this.routeIds,
    this.emphasizeIds,
    this.dimOthers = false,
  });

  static final Path _statePath = _buildStatePath();
  static final List<Offset> _coast = _buildCoast();

  static List<Offset> _buildCoast() {
    // Border points down to the Mexico corner are the coastline.
    final pts = <Offset>[];
    for (var i = 0; i < _border.length; i += 2) {
      pts.add(projectLL(_border[i], _border[i + 1]));
      if (_border[i] == 32.53) break; // last coastal point
    }
    return pts;
  }

  static Path _buildStatePath() {
    final path = Path();
    for (var i = 0; i < _border.length; i += 2) {
      final o = projectLL(_border[i], _border[i + 1]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = mapFitScale(size);
    final off = mapFitOffset(size, scale);
    canvas.save();
    canvas.translate(off.dx, off.dy);
    canvas.scale(scale);

    // ---- ocean: everything west of the coastline ----
    final ocean = Path()..moveTo(_coast.first.dx, _coast.first.dy);
    for (final c in _coast.skip(1)) {
      ocean.lineTo(c.dx, c.dy);
    }
    ocean
      ..lineTo(_coast.last.dx, kMapH + 6)
      ..lineTo(-6, kMapH + 6)
      ..lineTo(-6, _coast.first.dy)
      ..close();
    canvas.drawPath(
        ocean,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF16242A), Color(0xFF1A2E33)]
                : const [Color(0xFFBFD9D4), Color(0xFFA8CBC9)],
          ).createShader(const Rect.fromLTWH(0, 0, kMapW, kMapH)));
    // faint wave strokes
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = (dark ? Colors.white : const Color(0xFF5E8A86))
          .withOpacity(0.18);
    for (final w in const [
      (14.0, 120.0, 34.0), (8.0, 175.0, 26.0), (30.0, 226.0, 30.0),
      (55.0, 268.0, 26.0), (90.0, 300.0, 30.0), (20.0, 62.0, 24.0),
    ]) {
      canvas.drawLine(
          Offset(w.$1, w.$2), Offset(w.$1 + w.$3, w.$2), wave);
    }
    _rotatedText(canvas, 'PACIFIC  OCEAN', const Offset(38, 205), 0.95,
        8.5, (dark ? Colors.white : const Color(0xFF4E7A76)).withOpacity(0.5));

    // ---- state ----
    canvas.drawPath(
        _statePath.shift(const Offset(2.5, 3.5)),
        Paint()
          ..color = Colors.black.withOpacity(dark ? 0.5 : 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawPath(
        _statePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF2C4431), Color(0xFF3A4F33), Color(0xFF54502E)]
                : const [
                    Color(0xFF7FA06A),
                    Color(0xFFA8B578),
                    Color(0xFFC9B878),
                    Color(0xFFD8A95F)
                  ],
          ).createShader(const Rect.fromLTWH(0, 0, kMapW, kMapH)));
    canvas.drawPath(
        _statePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = dark ? const Color(0xFF11190F) : const Color(0xFF5F7350));

    // ---- ranges, from real crest coordinates ----
    final ridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = (dark ? const Color(0xFF1E2C1C) : const Color(0xFF6B7A4F))
          .withOpacity(0.5)
      ..strokeWidth = 5;
    _geoPolyline(canvas, ridge, const [
      36.58, -118.29, 37.20, -118.70, 37.90, -119.30, 38.70, -120.05,
      39.40, -120.60, 40.20, -121.20, // Sierra crest up toward Lassen
    ]);
    _geoPolyline(
        canvas,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..color = ridge.color.withOpacity(0.3)
          ..strokeWidth = 3.5,
        const [40.60, -123.40, 39.40, -123.30, 38.40, -122.90]);
    _rotatedText(
        canvas,
        'SIERRA NEVADA',
        projectLL(38.15, -119.35) + const Offset(6, 0),
        1.0,
        7.5,
        (dark ? const Color(0xFFB9C9A8) : const Color(0xFF4A5A38))
            .withOpacity(0.55));

    // ---- home ----
    final home = projectLL(kHomeLat, kHomeLon);
    _emoji(canvas, '🏠', home - const Offset(0, 1), 10);
    _text(canvas, 'MODESTO', home + const Offset(0, 6), 6.2,
        dark ? const Color(0xFFB9C9A8) : const Color(0xFF3C4A2F));

    // ---- route line under the pins ----
    final routePts = <Offset>[];
    if (routeIds != null) {
      for (final id in routeIds!) {
        for (final p in places) {
          if (p.id == id) {
            final pp = pinPos(p);
            if (pp != null) routePts.add(pp);
          }
        }
      }
      if (routePts.length > 1) {
        final rp = Path()..moveTo(routePts.first.dx, routePts.first.dy);
        for (final o in routePts.skip(1)) {
          rp.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(
            rp,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..color = P.poppy.withOpacity(0.85));
      }
    }

    // ---- pins ----
    for (final p in places) {
      final pp = pinPos(p);
      if (pp == null) continue;
      final isFocus = p.id == highlightId ||
          (routeIds?.contains(p.id) ?? false) ||
          (emphasizeIds?.contains(p.id) ?? false);
      final faded = dimOthers && !isFocus;
      final inSeason = p.season != null &&
          p.season!.inMonth(month) &&
          !doneIds.contains(p.id);
      var color = doneIds.contains(p.id)
          ? P.doneGreen
          : inSeason
              ? P.poppy
              : const Color(0xFF8F8F80);
      if (faded) color = color.withOpacity(0.45);
      if (inSeason && !faded && routeIds == null) {
        canvas.drawCircle(
            pp,
            4.5 + pulseT * 7,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = P.poppy.withOpacity((1 - pulseT) * 0.7));
      }
      canvas.drawCircle(pp, 4.2, Paint()..color = color);
      canvas.drawCircle(
          pp,
          4.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = (dark ? const Color(0xFF141B15) : const Color(0xFFFFFDF2))
                .withOpacity(faded ? 0.45 : 1));
    }

    // ---- numbered route stops on top ----
    for (var i = 0; i < routePts.length; i++) {
      canvas.drawCircle(routePts[i], 7, Paint()..color = P.pine);
      canvas.drawCircle(
          routePts[i],
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white);
      _text(canvas, '${i + 1}', routePts[i] - const Offset(0, 3.4), 7,
          Colors.white);
    }

    // ---- highlighted place on top of everything ----
    if (highlightId != null) {
      for (final p in places) {
        if (p.id != highlightId) continue;
        final pp = pinPos(p);
        if (pp == null) continue;
        canvas.drawCircle(
            pp,
            10 + pulseT * 5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = P.poppy.withOpacity((1 - pulseT) * 0.9));
        canvas.drawCircle(pp, 6.5, Paint()..color = P.poppy);
        canvas.drawCircle(
            pp,
            6.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white);
        final label = p.name.length > 26 ? '${p.name.substring(0, 24)}…' : p.name;
        _text(canvas, label, pp + const Offset(0, 9), 7.5,
            dark ? const Color(0xFFEDE6D2) : const Color(0xFF26331F));
      }
    }
    canvas.restore();
  }

  void _geoPolyline(Canvas canvas, Paint paint, List<double> latLons) {
    final path = Path();
    for (var i = 0; i < latLons.length; i += 2) {
      final o = projectLL(latLons[i], latLons[i + 1]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _text(Canvas canvas, String s, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: size,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, 0));
  }

  void _rotatedText(Canvas canvas, String s, Offset at, double angle,
      double size, Color color) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: size,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
              fontStyle: FontStyle.italic)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _emoji(Canvas canvas, String s, Offset center, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant PosterMapPainter old) =>
      old.pulseT != pulseT ||
      old.doneIds.length != doneIds.length ||
      old.dark != dark ||
      old.places.length != places.length ||
      old.highlightId != highlightId ||
      old.dimOthers != dimOthers ||
      (old.routeIds?.length ?? -1) != (routeIds?.length ?? -1) ||
      (old.emphasizeIds?.length ?? -1) != (emphasizeIds?.length ?? -1);
}
