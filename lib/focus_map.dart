import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'map_screen.dart';
import 'models.dart';
import 'place_sheet.dart';
import 'services.dart';
import 'store.dart';
import 'theme.dart';

/// Full-screen zoomable map focused on one place (see what's around it) or
/// one trip (see the route, spot places worth adding along the way).
class FocusMapPage extends StatefulWidget {
  final Place? place;
  final Trip? trip;
  const FocusMapPage({super.key, this.place, this.trip})
      : assert(place != null || trip != null);

  @override
  State<FocusMapPage> createState() => _FocusMapPageState();
}

class _FocusMapPageState extends State<FocusMapPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  final _tc = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _pulse.dispose();
    _tc.dispose();
    super.dispose();
  }

  List<String> _routeIds() {
    final t = widget.trip;
    if (t == null) return const [];
    return [
      for (final s in AppState.instance.stopsOf(t))
        if (s.placeId != null) s.placeId!,
    ];
  }

  List<Offset> _focusPoints() {
    final app = AppState.instance;
    final pts = <Offset>[];
    if (widget.place != null) {
      final o = pinPos(widget.place!);
      if (o != null) pts.add(o);
    } else {
      for (final id in _routeIds()) {
        final p = app.place(id);
        if (p != null) {
          final o = pinPos(p);
          if (o != null) pts.add(o);
        }
      }
    }
    return pts;
  }

  void _applyInitialZoom(Size size) {
    if (_zoomed) return;
    _zoomed = true;
    final pts = _focusPoints();
    if (pts.isEmpty) return;
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final o in pts) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }
    final span = (math.max(maxX - minX, maxY - minY) + 90).clamp(70.0, kMapW);
    final scale0 = mapFitScale(size);
    final off = mapFitOffset(size, scale0);
    final z = (math.min(size.width, size.height) / (span * scale0))
        .clamp(1.0, 5.0);
    final centerPx = Offset(
      off.dx + (minX + maxX) / 2 * scale0,
      off.dy + (minY + maxY) / 2 * scale0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tc.value = Matrix4.identity()
        ..translate(size.width / 2, size.height / 2)
        ..scale(z)
        ..translate(-centerPx.dx, -centerPx.dy);
    });
  }

  /// Nearby candidates: place mode = closest to the place; trip mode =
  /// within reach of ANY stop and not already on the trip.
  List<(Place, double)> _nearby() {
    final app = AppState.instance;
    final out = <(Place, double)>[];
    if (widget.place != null) {
      final f = widget.place!;
      if (f.ll == null) return out;
      for (final p in app.allPlaces) {
        if (p.id == f.id || p.ll == null) continue;
        final d = milesBetween(f.ll![0], f.ll![1], p.ll![0], p.ll![1]);
        if (d <= 60) out.add((p, d));
      }
    } else {
      final t = widget.trip!;
      final stops = [
        for (final id in _routeIds())
          if (app.place(id)?.ll != null) app.place(id)!,
      ];
      if (stops.isEmpty) return out;
      for (final p in app.allPlaces) {
        if (p.ll == null || app.tripHasPlace(t, p.id)) continue;
        var best = double.infinity;
        for (final s in stops) {
          best = math.min(
              best, milesBetween(s.ll![0], s.ll![1], p.ll![0], p.ll![1]));
        }
        if (best <= 35) out.add((p, best));
      }
    }
    out.sort((a, b) => a.$2.compareTo(b.$2));
    return out.take(14).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final title = widget.place?.name ?? widget.trip!.name;
    final nearby = _nearby();
    final month = DateTime.now().month;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
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
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: serif(context, size: 18)),
                ),
                Text('pinch to zoom',
                    style: TextStyle(fontSize: 10.5, color: context.ink2)),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, cons) {
                final size = Size(cons.maxWidth, cons.maxHeight);
                _applyInitialZoom(size);
                return ClipRect(
                  child: InteractiveViewer(
                    transformationController: _tc,
                    maxScale: 8,
                    child: GestureDetector(
                      onTapUp: (d) => _onTap(d.localPosition, size),
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => CustomPaint(
                          painter: PosterMapPainter(
                            places: app.allPlaces,
                            doneIds: app.done.keys.toSet(),
                            month: month,
                            pulseT: _pulse.value,
                            dark: context.isDark,
                            highlightId: widget.place?.id,
                            routeIds:
                                widget.trip == null ? null : _routeIds(),
                            dimOthers: true,
                          ),
                          size: size,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Container(
              height: 252,
              decoration: BoxDecoration(
                color: context.card,
                border: Border(top: BorderSide(color: context.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                    child: Text(
                      widget.place != null
                          ? 'NEARBY — CLOSEST FIRST'
                          : 'WORTH ADDING ALONG THE WAY',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: P.poppy),
                    ),
                  ),
                  Expanded(
                    child: nearby.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                widget.place != null
                                    ? 'Nothing else from your list within 60 miles — this one\'s a destination of its own.'
                                    : 'Nothing from your list sits within 35 miles of this route.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5, color: context.ink2),
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                            children: [
                              for (final (p, mi) in nearby)
                                _nearbyRow(context, p, mi, month),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearbyRow(BuildContext context, Place p, double mi, int month) {
    final app = AppState.instance;
    final t = widget.trip;
    final inSeason = p.season != null && p.season!.inMonth(month);
    final done = app.isDone(p.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        child: ListTile(
          dense: true,
          onTap: () async {
            await showPlaceSheet(context, p);
            setState(() {});
          },
          leading: SizedBox(
            width: 38,
            height: 38,
            child:
                PlacePhoto(p, height: 38, radius: BorderRadius.circular(9)),
          ),
          title: Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: done ? context.ink2 : context.ink,
                decoration: done ? TextDecoration.lineThrough : null,
              )),
          subtitle: Text(
            [
              '~${mi.round()} mi',
              if (inSeason) 'in season now',
              if (p.season != null && !inSeason) 'seasonal',
            ].join(' · '),
            style: TextStyle(fontSize: 11, color: context.ink2),
          ),
          trailing: t == null
              ? Icon(Icons.chevron_right, size: 18, color: context.ink2)
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: P.pine,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    app.addTripExtra(t.id, p.id);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Added "${p.name}" to ${t.name}')));
                  },
                  child: const Text('+ Add'),
                ),
        ),
      ),
    );
  }

  void _onTap(Offset pos, Size size) {
    final scale = mapFitScale(size);
    final off = mapFitOffset(size, scale);
    Place? best;
    double bestD = 16;
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
    if (best != null) {
      showPlaceSheet(context, best).then((_) => setState(() {}));
    }
  }
}
