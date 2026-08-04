import 'package:flutter/material.dart';

import 'models.dart';
import 'more_screen.dart' show openWeekendPicker, RecapPage;
import 'place_sheet.dart';
import 'store.dart';
import 'theme.dart';

/// The poster map. All pin coords live in a 300x330 design space
/// (data/overrides.json) and are scaled to fit.
const double kMapW = 300, kMapH = 330;

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
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: (d) => _onMapTap(context, d.localPosition),
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
                        size: Size.infinite,
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
            ),
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

  void _onMapTap(BuildContext context, Offset pos) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null) return;
    // Same fit math as the painter.
    final mapSize = Size(size.width, size.height - 0); // stack fills
    final scale = _fitScale(mapSize);
    final off = _fitOffset(mapSize, scale);
    Place? best;
    double bestD = 18; // touch slop in px
    for (final p in AppState.instance.allPlaces) {
      if (p.pin == null) continue;
      final px = off.dx + p.pin![0] * scale;
      final py = off.dy + p.pin![1] * scale;
      final d = (Offset(px, py) - pos).distance;
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    if (best != null) showPlaceSheet(context, best);
  }
}

double _fitScale(Size s) {
  final sx = s.width / kMapW, sy = s.height / kMapH;
  return sx < sy ? sx : sy;
}

Offset _fitOffset(Size s, double scale) => Offset(
    (s.width - kMapW * scale) / 2, (s.height - kMapH * scale) / 2);

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

/// Hand-drawn California in the national-park-poster register.
class PosterMapPainter extends CustomPainter {
  final List<Place> places;
  final Set<String> doneIds;
  final int month;
  final double pulseT;
  final bool dark;

  PosterMapPainter({
    required this.places,
    required this.doneIds,
    required this.month,
    required this.pulseT,
    required this.dark,
  });

  static final Path _statePath = Path()
    ..moveTo(32, 12)
    ..lineTo(150, 12)
    ..lineTo(150, 96)
    ..lineTo(253, 224)
    ..lineTo(256, 236)
    ..lineTo(249, 243)
    ..lineTo(254, 252)
    ..lineTo(250, 262)
    ..lineTo(178, 274)
    ..lineTo(156, 251)
    ..lineTo(138, 244)
    ..lineTo(122, 236)
    ..lineTo(108, 214)
    ..lineTo(94, 188)
    ..lineTo(88, 170)
    ..lineTo(80, 158)
    ..lineTo(74, 140)
    ..lineTo(64, 116)
    ..lineTo(52, 82)
    ..lineTo(44, 58)
    ..lineTo(36, 34)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _fitScale(size);
    final off = _fitOffset(size, scale);
    canvas.save();
    canvas.translate(off.dx, off.dy);
    canvas.scale(scale);

    // soft drop shadow
    canvas.drawPath(
        _statePath.shift(const Offset(3, 4)),
        Paint()
          ..color = Colors.black.withOpacity(dark ? 0.5 : 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // land
    final land = Paint()
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
      ).createShader(const Rect.fromLTWH(0, 0, kMapW, kMapH));
    canvas.drawPath(_statePath, land);
    canvas.drawPath(
        _statePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = dark ? const Color(0xFF11190F) : const Color(0xFF5F7350));

    // Sierra ridge + coast range hints
    final ridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = (dark ? const Color(0xFF1E2C1C) : const Color(0xFF6B7A4F))
          .withOpacity(0.5)
      ..strokeWidth = 5;
    canvas.drawPath(
        Path()
          ..moveTo(138, 30)
          ..lineTo(146, 60)
          ..lineTo(156, 96)
          ..lineTo(172, 130)
          ..lineTo(190, 168),
        ridge);
    canvas.drawPath(
        Path()
          ..moveTo(60, 40)
          ..quadraticBezierTo(80, 90, 96, 150),
        ridge
          ..strokeWidth = 4
          ..color = ridge.color.withOpacity(0.35));

    // home
    _emoji(canvas, '🏠', const Offset(97, 148), 11);
    _text(canvas, 'MODESTO', const Offset(97, 158), 6.5,
        dark ? const Color(0xFFB9C9A8) : const Color(0xFF3C4A2F));

    // pins
    for (final p in places) {
      if (p.pin == null) continue;
      final c = Offset(p.pin![0], p.pin![1]);
      final inSeason =
          p.season != null && p.season!.inMonth(month) && !doneIds.contains(p.id);
      final color = doneIds.contains(p.id)
          ? P.doneGreen
          : inSeason
              ? P.poppy
              : const Color(0xFF8F8F80);
      if (inSeason) {
        final r = 5 + pulseT * 7;
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = P.poppy.withOpacity((1 - pulseT) * 0.7));
      }
      canvas.drawCircle(c, 4.4, Paint()..color = color);
      canvas.drawCircle(
          c,
          4.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = dark ? const Color(0xFF141B15) : const Color(0xFFFFFDF2));
    }
    canvas.restore();
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
      old.places.length != places.length;
}
