import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'trip_readiness.dart';

/// Forecast for the route midpoint, using Open-Meteo's public forecast API.
/// It is a point estimate, not a mountain hazard or avalanche forecast.
Future<WeatherSnapshot> fetchRouteWeather(
  HikingRoute route, {
  http.Client? client,
}) async {
  final ownClient = client == null;
  client ??= http.Client();
  try {
    final point = route.points[route.points.length ~/ 2];
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': point[1].toString(),
      'longitude': point[0].toString(),
      'hourly': 'weather_code,wind_speed_10m,precipitation_probability',
      'daily': 'sunset',
      'timezone': 'auto',
      'timeformat': 'unixtime',
      'forecast_days': '2',
    });
    final response = await client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Погода недоступна (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<num>();
    final now = DateTime.now();
    final from = times.indexWhere(
      (time) => !DateTime.fromMillisecondsSinceEpoch(
        time.round() * 1000,
      ).isBefore(now.subtract(const Duration(minutes: 30))),
    );
    if (from < 0) throw StateError('Нет прогноза на ближайшие часы.');
    final end = from + 6 > times.length ? times.length : from + 6;
    final winds = (hourly['wind_speed_10m'] as List)
        .sublist(from, end)
        .cast<num>();
    final rain = (hourly['precipitation_probability'] as List)
        .sublist(from, end)
        .cast<num>();
    final codes = (hourly['weather_code'] as List)
        .sublist(from, end)
        .cast<num>();
    final sunsets = (data['daily'] as Map<String, dynamic>)['sunset'] as List;
    final sunset = sunsets
        .map(
          (value) => DateTime.fromMillisecondsSinceEpoch(
            (value as num).round() * 1000,
          ),
        )
        .where((value) => value.isAfter(now))
        .firstOrNull;
    return WeatherSnapshot(
      fetchedAt: now,
      routeId: route.id,
      windKmh: winds
          .map((value) => value.toDouble())
          .reduce((a, b) => a > b ? a : b),
      rainChance: rain
          .map((value) => value.round())
          .reduce((a, b) => a > b ? a : b),
      weatherCode: codes
          .map((value) => value.round())
          .reduce((a, b) => a > b ? a : b),
      sunset: sunset,
    );
  } finally {
    if (ownClient) client.close();
  }
}
