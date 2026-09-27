import 'dart:math' as math;
import 'models.dart';

class RouteProfile {
  const RouteProfile(this.distanceKm, this.ascentM, this.hours, this.level);
  final double distanceKm;
  final int ascentM;
  final double hours;
  final String level;

  static RouteProfile fromRoute(
    HikingRoute route,
    Map<String, dynamic> terrain,
  ) {
    final distanceKm = route.distance / 1000;
    final ascent = routeAscent(route, terrain);
    final hours = distanceKm / 3 + ascent / 450;
    final level = distanceKm >= 12 || ascent >= 900 || hours >= 6
        ? 'Сложный'
        : distanceKm >= 6 || ascent >= 450 || hours >= 3.5
        ? 'Средний'
        : 'Лёгкий';
    return RouteProfile(distanceKm, ascent, hours, level);
  }
}

double terrainHeight(Map<String, dynamic> terrain, double lon, double lat) {
  final width = terrain['width'] as int;
  final heights = terrain['heights'] as List;
  final west = (terrain['west'] as num).toDouble();
  final east = (terrain['east'] as num).toDouble();
  final south = (terrain['south'] as num).toDouble();
  final north = (terrain['north'] as num).toDouble();
  final x = ((lon - west) / (east - west) * (width - 1)).clamp(
    0.0,
    (width - 1).toDouble(),
  );
  final y = ((north - lat) / (north - south) * (width - 1)).clamp(
    0.0,
    (width - 1).toDouble(),
  );
  final i = math.min(width - 2, x.floor());
  final j = math.min(width - 2, y.floor());
  final fx = x - i, fy = y - j;
  final a =
      (heights[j * width + i] as num).toDouble() * (1 - fx) +
      (heights[j * width + i + 1] as num).toDouble() * fx;
  final b =
      (heights[(j + 1) * width + i] as num).toDouble() * (1 - fx) +
      (heights[(j + 1) * width + i + 1] as num).toDouble() * fx;
  return a * (1 - fy) + b * fy;
}

int routeAscent(HikingRoute route, Map<String, dynamic> terrain) {
  var ascent = 0.0;
  double? previous;
  for (var i = 1; i < route.points.length; i++) {
    final a = route.points[i - 1], b = route.points[i];
    final meters = distanceMeters(a[1], a[0], b[1], b[0]);
    final steps = math.max(1, (meters / 100).ceil());
    for (var k = i == 1 ? 0 : 1; k <= steps; k++) {
      final t = k / steps;
      final height = terrainHeight(
        terrain,
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
      );
      if (previous != null) ascent += math.max(0, height - previous);
      previous = height;
    }
  }
  return ascent.round();
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.fetchedAt,
    required this.routeId,
    required this.windKmh,
    required this.rainChance,
    required this.weatherCode,
    this.sunset,
  });
  final DateTime fetchedAt;
  final String routeId;
  final double windKmh;
  final int rainChance;
  final int weatherCode;
  final DateTime? sunset;

  bool freshAt(DateTime now) =>
      now.difference(fetchedAt).abs() <= const Duration(hours: 2);
  bool get thunderstorm => weatherCode >= 95;
  bool get snowOrIce =>
      weatherCode == 56 ||
      weatherCode == 57 ||
      weatherCode == 66 ||
      weatherCode == 67 ||
      (weatherCode >= 71 && weatherCode <= 77) ||
      (weatherCode >= 85 && weatherCode <= 86);
  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toIso8601String(),
    'routeId': routeId,
    'windKmh': windKmh,
    'rainChance': rainChance,
    'weatherCode': weatherCode,
    'sunset': sunset?.toIso8601String(),
  };
  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) =>
      WeatherSnapshot(
        fetchedAt: DateTime.parse(json['fetchedAt']),
        routeId: json['routeId'],
        windKmh: (json['windKmh'] as num).toDouble(),
        rainChance: (json['rainChance'] as num).round(),
        weatherCode: (json['weatherCode'] as num).round(),
        sunset: DateTime.tryParse(json['sunset'] ?? ''),
      );
}

class Readiness {
  const Readiness(this.level, this.reasons);
  final int level; // 0: ready, 1: check, 2: postpone
  final List<String> reasons;
  String get title => switch (level) {
    2 => 'Выход лучше отложить',
    1 => 'Проверьте условия',
    _ => 'Основные проверки пройдены',
  };
}

Readiness assessTrip({
  required RouteProfile profile,
  required DateTime now,
  required DateTime? turnAt,
  required DateTime? returnAt,
  required WeatherSnapshot? weather,
  required int? battery,
  required int checkedItems,
  required int totalItems,
  required bool hasContact,
  required bool demo,
}) {
  final reasons = <String>[];
  var level = 0;
  void flag(int severity, String text) {
    level = math.max(level, severity);
    reasons.add(text);
  }

  if (demo) {
    flag(1, 'Включён демо-маршрут: для похода нужен проверенный маршрут.');
  }
  if (weather == null || !weather.freshAt(now)) {
    flag(
      1,
      'Нет свежего прогноза для этого маршрута. Проверьте погоду перед выходом.',
    );
  } else {
    if (weather.thunderstorm) flag(2, 'Прогноз сообщает о грозе.');
    if (weather.snowOrIce) {
      flag(2, 'Прогноз сообщает о снеге или ледяных осадках.');
    }
    if (weather.windKmh >= 55) {
      flag(2, 'Ожидается сильный ветер: ${weather.windKmh.round()} км/ч.');
    } else if (weather.windKmh >= 35) {
      flag(1, 'Ветер до ${weather.windKmh.round()} км/ч.');
    }
    if (weather.rainChance >= 75) {
      flag(1, 'Вероятность осадков до ${weather.rainChance}%.');
    }
    final expectedEnd =
        returnAt ?? now.add(Duration(minutes: (profile.hours * 60).ceil()));
    if (weather.sunset != null && expectedEnd.isAfter(weather.sunset!)) {
      flag(2, 'Планируемое возвращение позже заката.');
    }
  }
  if (battery == null) {
    flag(1, 'Заряд телефона не определён.');
  } else if (battery <= 20) {
    flag(2, 'Заряд телефона $battery% — зарядите его перед выходом.');
  } else if (battery <= 40) {
    flag(1, 'Заряд телефона $battery% — возьмите пауэрбанк.');
  }
  if (checkedItems < totalItems) {
    flag(1, 'Снаряжение: отмечено $checkedItems из $totalItems пунктов.');
  }
  if (!hasContact) flag(1, 'Не указан близкий человек для плана похода.');
  if (returnAt == null || turnAt == null) {
    flag(1, 'Укажите время разворота и возвращения.');
  }
  if (returnAt != null && !returnAt.isAfter(now)) {
    flag(2, 'Планируемое время возвращения уже прошло.');
  }
  if (returnAt != null &&
      returnAt.isBefore(
        now.add(Duration(minutes: (profile.hours * 60).ceil())),
      )) {
    flag(1, 'Запланированное время меньше примерной длительности маршрута.');
  }
  if (profile.level == 'Сложный') {
    flag(1, 'Сложный маршрут: оцените опыт группы и условия на тропе.');
  }
  if (reasons.isEmpty) {
    reasons.add('Маршрут, время, погода, заряд и снаряжение проверены.');
  }
  return Readiness(level, reasons);
}
