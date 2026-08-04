/// Data models. The seed (regions/places/trips) is generated from
/// data/california-trip-planner.md and never edited by the app; everything
/// the user changes lives in the Overlay (store.dart).

class Season {
  final String label;
  final List<int> months; // 1-12
  final bool hard; // hard window (closed/unsafe outside) vs merely best-time

  Season({required this.label, required this.months, required this.hard});

  factory Season.fromJson(Map<String, dynamic> j) => Season(
        label: j['label'] as String? ?? '',
        months: (j['months'] as List? ?? const []).map((e) => e as int).toList(),
        hard: (j['type'] as String? ?? 'best') == 'hard',
      );

  bool inMonth(int m) => months.contains(m);

  /// Last month of the contiguous run containing [m] (wrapping year-end),
  /// or null if [m] is outside the window.
  int? runEnd(int m) {
    if (!inMonth(m)) return null;
    var cur = m;
    for (var i = 0; i < 12; i++) {
      final next = cur == 12 ? 1 : cur + 1;
      if (!months.contains(next)) return cur;
      cur = next;
    }
    return null; // year-round
  }

  /// First month of the next (or current) opening after month [m].
  int? nextOpening(int m) {
    for (var i = 1; i <= 12; i++) {
      final probe = ((m - 1 + i) % 12) + 1;
      final prev = probe == 1 ? 12 : probe - 1;
      if (months.contains(probe) && !months.contains(prev)) return probe;
    }
    return null;
  }
}

class Place {
  final String id;
  final String name;
  final String region;
  final String? loc;
  final String? desc;
  final Season? season;
  final List<double>? pin; // x,y in 300x330 poster-map space
  final List<double>? ll; // lat, lon
  final bool custom;

  Place({
    required this.id,
    required this.name,
    required this.region,
    this.loc,
    this.desc,
    this.season,
    this.pin,
    this.ll,
    this.custom = false,
  });

  factory Place.fromJson(Map<String, dynamic> j, {bool custom = false}) => Place(
        id: j['id'] as String,
        name: j['name'] as String,
        region: j['region'] as String,
        loc: j['loc'] as String?,
        desc: j['desc'] as String?,
        season: j['season'] == null
            ? null
            : Season.fromJson(j['season'] as Map<String, dynamic>),
        pin: (j['pin'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        ll: (j['ll'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        custom: custom,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        if (loc != null) 'loc': loc,
        if (desc != null) 'desc': desc,
        if (season != null)
          'season': {
            'label': season!.label,
            'months': season!.months,
            'type': season!.hard ? 'hard' : 'best',
          },
        if (pin != null) 'pin': pin,
        if (ll != null) 'll': ll,
      };
}

class TripStop {
  final String text;
  final String? placeId;
  TripStop({required this.text, this.placeId});
  factory TripStop.fromJson(Map<String, dynamic> j) =>
      TripStop(text: j['text'] as String, placeId: j['placeId'] as String?);
  Map<String, dynamic> toJson() =>
      {'text': text, if (placeId != null) 'placeId': placeId};
}

class Trip {
  final String id;
  final String name;
  final String tier;
  final List<TripStop> stops;
  final String? season;
  final bool custom;

  Trip({
    required this.id,
    required this.name,
    required this.tier,
    required this.stops,
    this.season,
    this.custom = false,
  });

  factory Trip.fromJson(Map<String, dynamic> j, {bool custom = false}) => Trip(
        id: j['id'] as String,
        name: j['name'] as String,
        tier: j['tier'] as String? ?? '',
        stops: (j['stops'] as List? ?? const [])
            .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        season: j['season'] as String?,
        custom: custom,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tier': tier,
        'stops': stops.map((s) => s.toJson()).toList(),
        if (season != null) 'season': season,
      };
}

class Region {
  final String id;
  final String name;
  Region({required this.id, required this.name});
  factory Region.fromJson(Map<String, dynamic> j) =>
      Region(id: j['id'] as String, name: j['name'] as String);
}

class Seed {
  final int version;
  final List<Region> regions;
  final List<Place> places;
  final List<Trip> trips;

  Seed({
    required this.version,
    required this.regions,
    required this.places,
    required this.trips,
  });

  factory Seed.fromJson(Map<String, dynamic> j) => Seed(
        version: (j['version'] as num?)?.toInt() ?? 0,
        regions: (j['regions'] as List? ?? const [])
            .map((r) => Region.fromJson(r as Map<String, dynamic>))
            .toList(),
        places: (j['places'] as List? ?? const [])
            .map((p) => Place.fromJson(p as Map<String, dynamic>))
            .toList(),
        trips: (j['trips'] as List? ?? const [])
            .map((t) => Trip.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

/// A planned outing: a trip (seed or custom) attached to real dates.
class Plan {
  final String tripId;
  final DateTime start;
  final DateTime end;
  Plan({required this.tripId, required this.start, required this.end});
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        tripId: j['tripId'] as String,
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
      );
  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'start': start.toIso8601String().substring(0, 10),
        'end': end.toIso8601String().substring(0, 10),
      };
}

class Reservation {
  final String id;
  final String title;
  final String note;
  final DateTime? bookBy;
  bool booked;
  Reservation({
    required this.id,
    required this.title,
    this.note = '',
    this.bookBy,
    this.booked = false,
  });
  factory Reservation.fromJson(Map<String, dynamic> j) => Reservation(
        id: j['id'] as String,
        title: j['title'] as String,
        note: j['note'] as String? ?? '',
        bookBy:
            j['bookBy'] == null ? null : DateTime.parse(j['bookBy'] as String),
        booked: j['booked'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        if (bookBy != null) 'bookBy': bookBy!.toIso8601String().substring(0, 10),
        'booked': booked,
      };
}
