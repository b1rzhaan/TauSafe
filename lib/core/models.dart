import 'dart:math' as math;

class Place {
  Place(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'];
  String get name => data['name'];
  String get kind => data['kind'];
  String get description => data['description'];
  String get image => data['image'] ?? '';
  double? get lat => (data['lat'] as num?)?.toDouble();
  double? get lon => (data['lon'] as num?)?.toDouble();
  String get source => data['source'];
  // Old offline catalogs predate these optional editorial fields.
  Map<String, dynamic> get story => {
    'tagline': description,
    'lead': description,
    'moments': <Map<String, dynamic>>[],
    'visitNote': 'Перед поездкой уточните доступность места и погоду.',
    'source': source,
    if (data['story'] is Map) ...Map<String, dynamic>.from(data['story']),
  };
  String get tagline => story['tagline']?.toString() ?? description;
  List<Map<String, dynamic>> get gallery {
    final raw = data['gallery'];
    if (raw is List && raw.isNotEmpty) {
      final items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (items.isNotEmpty) return items;
    }
    return [
      {
        'image': image,
        'caption': name,
        'photo':
            data['photo'] ??
            {
              'page': source,
              'author': 'Источник места',
              'license': 'См. источник',
            },
      },
    ];
  }
}

class TrackPoint {
  const TrackPoint(
    this.lat,
    this.lon,
    this.time, {
    this.accuracy = 8,
    this.demo = false,
    this.segment = 0,
  });
  final double lat, lon, accuracy;
  final DateTime time;
  final bool demo;
  final int segment;
  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lon': lon,
    'accuracy': accuracy,
    'time': time.toIso8601String(),
    'demo': demo,
    'segment': segment,
  };
  factory TrackPoint.fromJson(Map<String, dynamic> j) => TrackPoint(
    (j['lat'] as num).toDouble(),
    (j['lon'] as num).toDouble(),
    DateTime.parse(j['time']),
    accuracy: (j['accuracy'] as num).toDouble(),
    demo: j['demo'] == true,
    segment: j['segment'] ?? 0,
  );
  String get coordinates =>
      '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
}

class HikingRoute {
  HikingRoute({
    required this.id,
    required this.name,
    required this.points,
    this.demo = false,
    this.source = 'Пользовательский импорт; не проверен',
    this.placeId = 'kok',
  });
  final String id, name, source, placeId;
  final List<List<double>> points; // GeoJSON [longitude, latitude]
  final bool demo;
  double get distance {
    double result = 0;
    for (var i = 1; i < points.length; i++) {
      result += distanceMeters(
        points[i - 1][1],
        points[i - 1][0],
        points[i][1],
        points[i][0],
      );
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points,
    'demo': demo,
    'source': source,
    'placeId': placeId,
  };
  factory HikingRoute.fromJson(Map<String, dynamic> j) => HikingRoute(
    id: j['id'],
    name: j['name'],
    points: (j['points'] as List)
        .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
        .toList(),
    demo: j['demo'] == true,
    source: j['source'],
    placeId: j['placeId'] ?? 'kok',
  );
  static HikingRoute fromGeoJson(Map<String, dynamic> json) {
    final feature = json['type'] == 'FeatureCollection'
        ? (json['features'] as List).firstWhere(
            (f) => f['geometry']?['type'] == 'LineString',
            orElse: () =>
                throw const FormatException('Нужен объект LineString'),
          )
        : json;
    final geometry = feature['type'] == 'Feature'
        ? feature['geometry']
        : feature;
    if (geometry['type'] != 'LineString') {
      throw const FormatException('Поддерживается GeoJSON LineString');
    }
    final raw = geometry['coordinates'] as List;
    if (raw.length < 2 || raw.length > 20000) {
      throw const FormatException('Нужно от 2 до 20 000 точек');
    }
    final pts = raw.map((e) {
      if (e is! List || e.length < 2 || e[0] is! num || e[1] is! num) {
        throw const FormatException('Неверные координаты');
      }
      final lon = (e[0] as num).toDouble(), lat = (e[1] as num).toDouble();
      if (!lon.isFinite || !lat.isFinite || lon.abs() > 180 || lat.abs() > 85) {
        throw const FormatException('Координаты вне диапазона');
      }
      return [lon, lat];
    }).toList();
    return HikingRoute(
      id: 'import-${DateTime.now().microsecondsSinceEpoch}',
      name:
          feature['properties']?['name']?.toString() ??
          'Импортированный маршрут',
      points: pts,
    );
  }
}

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0, rad = math.pi / 180;
  final a =
      math.pow(math.sin((lat2 - lat1) * rad / 2), 2) +
      math.cos(lat1 * rad) *
          math.cos(lat2 * rad) *
          math.pow(math.sin((lon2 - lon1) * rad / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.clamp(0, 1)));
}

class HikeSession {
  HikeSession({
    required this.id,
    required this.routeId,
    required this.demo,
    required this.started,
    this.status = 'active',
    this.elapsedSeconds = 0,
    List<TrackPoint>? points,
  }) : points = points ?? [];
  final String id, routeId;
  final bool demo;
  final DateTime started;
  String status;
  int elapsedSeconds;
  List<TrackPoint> points;
  double get distance {
    double d = 0;
    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (a.segment == b.segment && a.demo == b.demo) {
        d += distanceMeters(a.lat, a.lon, b.lat, b.lon);
      }
    }
    return d;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'routeId': routeId,
    'demo': demo,
    'started': started.toIso8601String(),
    'status': status,
    'elapsedSeconds': elapsedSeconds,
    'points': points.map((e) => e.toJson()).toList(),
  };
  factory HikeSession.fromJson(Map<String, dynamic> j) => HikeSession(
    id: j['id'],
    routeId: j['routeId'],
    demo: j['demo'],
    started: DateTime.parse(j['started']),
    status: j['status'],
    elapsedSeconds: j['elapsedSeconds'] ?? 0,
    points: (j['points'] as List)
        .map((e) => TrackPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

const checklistItems = [
  'Вода',
  'Подходящая одежда',
  'Заряженный телефон',
  'Пауэрбанк',
  'Фонарь',
  'Аптечка',
  'Маршрут передан близкому',
];
