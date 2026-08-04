import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'services.dart';
import 'store.dart';
import 'theme.dart';

// ---------------------------------------------------------- wiki thumbnails
final Map<String, String?> _thumbCache = {};

Future<String?> wikiThumb(Place p) async {
  if (_thumbCache.containsKey(p.id)) return _thumbCache[p.id];
  try {
    final title = Uri.encodeComponent(p.name.replaceAll(' ', '_'));
    final res = await http
        .get(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$title'))
        .timeout(const Duration(seconds: 8));
    String? url;
    if (res.statusCode == 200) {
      final j = json.decode(res.body) as Map<String, dynamic>;
      url = (j['thumbnail'] as Map<String, dynamic>?)?['source'] as String?;
    }
    _thumbCache[p.id] = url;
    return url;
  } catch (_) {
    _thumbCache[p.id] = null;
    return null;
  }
}

/// Photo header: Wikipedia thumb when it exists, poster gradient otherwise.
class PlacePhoto extends StatelessWidget {
  final Place place;
  final double height;
  final BorderRadius? radius;
  const PlacePhoto(this.place, {super.key, this.height = 150, this.radius});

  @override
  Widget build(BuildContext context) {
    final r = radius ?? const BorderRadius.vertical(top: Radius.circular(24));
    return FutureBuilder<String?>(
      future: wikiThumb(place),
      builder: (context, snap) {
        final url = snap.data;
        return ClipRRect(
          borderRadius: r,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A5A44), Color(0xFF1D2C22)],
              ),
            ),
            child: Stack(fit: StackFit.expand, children: [
              if (url != null)
                Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55)
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 12,
                child: Text(place.name,
                    style: serif(context, size: 22, color: Colors.white)),
              ),
              if (url != null)
                Positioned(
                  top: 10,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('photo · Wikipedia',
                        style: TextStyle(fontSize: 9, color: Colors.white)),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------- the sheet
Future<void> showPlaceSheet(BuildContext context, Place place) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlaceSheet(place: place),
  );
}

class _PlaceSheet extends StatefulWidget {
  final Place place;
  const _PlaceSheet({required this.place});
  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final p = widget.place;
    final s = p.season;
    final month = DateTime.now().month;
    final inSeason = s != null && s.inMonth(month);
    final done = app.isDone(p.id);
    final drive = driveTimeFromHome(p);

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // SafeArea keeps the sheet's buttons above Android's own navigation bar.
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PlacePhoto(p),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    SeasonPill(app.region(p.region)?.name ?? '', 'best'),
                    if (inSeason) const SeasonPill('in season now', 'now'),
                    if (drive != null) SeasonPill('$drive from home', 'best'),
                    if (done) const SeasonPill('done', 'done'),
                  ]),
                  if ((p.desc ?? '').isNotEmpty || (p.loc ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      [
                        if ((p.desc ?? '').isNotEmpty) p.desc,
                        if ((p.loc ?? '').isNotEmpty) p.loc,
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 13.5, color: context.ink2, height: 1.45),
                    ),
                  ],
                  if (s != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: s.hard
                            ? (context.isDark
                                ? const Color(0xFF4A2A12)
                                : const Color(0xFFFBDCC5))
                            : context.line,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${s.hard ? '⏳ Hard window' : '☀️ Best time'}: ${s.label}'
                        '${inSeason ? '  ·  open right now' : ''}',
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: s.hard
                                ? (context.isDark
                                    ? const Color(0xFFF3B98A)
                                    : const Color(0xFF7C3806))
                                : context.ink2),
                      ),
                    ),
                  ],
                  if (p.ll != null) ...[
                    const SizedBox(height: 12),
                    _WeatherRow(lat: p.ll![0], lon: p.ll![1]),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                      onPressed: () => launchUrl(
                          Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${p.name} California')}'),
                          mode: LaunchMode.externalApplication),
                      child: const Text('🧭 Directions',
                          style: TextStyle(fontSize: 12)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton(
                      onPressed: () => launchUrl(
                          Uri.parse(
                              'https://www.google.com/search?q=${Uri.encodeComponent('${p.name} California hours official')}'),
                          mode: LaunchMode.externalApplication),
                      child: const Text('🌐 Info & hours',
                          style: TextStyle(fontSize: 12)),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(children: [
                        DoneCircle(
                          on: done,
                          onTap: () {
                            app.toggleDone(p.id);
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(done ? 'Done' : 'Not done yet',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.ink)),
                              Text(
                                done
                                    ? _pretty(app.done[p.id]!)
                                    : 'Tap the circle when you go',
                                style: TextStyle(
                                    fontSize: 11.5, color: context.ink2),
                              ),
                            ],
                          ),
                        ),
                        if (done)
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.parse(app.done[p.id]!),
                                firstDate: DateTime(2015),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                app.setDoneDate(p.id, picked);
                                setState(() {});
                              }
                            },
                            child: const Text('Edit date',
                                style: TextStyle(fontSize: 12)),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          if (p.custom) {
                            app.removeCustomPlace(p.id);
                          } else {
                            app.hide(p.id);
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(p.custom
                                  ? 'Deleted "${p.name}"'
                                  : 'Hidden — restore any time in Settings')));
                        },
                        child: Text(
                            p.custom ? 'Delete place' : 'Remove from my list',
                            style: const TextStyle(
                                color: Color(0xFFB3520A),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      FilledButton(
                        style:
                            FilledButton.styleFrom(backgroundColor: P.poppy),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String _pretty(String iso) {
    final d = DateTime.parse(iso);
    const mo = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    return '${mo[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _WeatherRow extends StatelessWidget {
  final double lat, lon;
  const _WeatherRow({required this.lat, required this.lon});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DayForecast>?>(
      future: forecast(lat, lon),
      builder: (context, snap) {
        final days = snap.data;
        if (days == null || days.isEmpty) return const SizedBox.shrink();
        const dows = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
        return Row(
          children: [
            for (final d in days.take(4)) ...[
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(children: [
                      Text(dows[d.date.weekday - 1],
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: context.ink2)),
                      const SizedBox(height: 2),
                      Text(d.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('${d.hi.round()}°',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: context.ink)),
                    ]),
                  ),
                ),
              ),
              if (d != days.take(4).last) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}
