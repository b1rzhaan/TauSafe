import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tausafe/core/models.dart';
import 'package:tausafe/core/trip_readiness.dart';
import 'package:tausafe/core/weather_service.dart';

void main() {
  final route = HikingRoute(
    id: 'r',
    name: 'Тест',
    points: [
      [77.0, 43.1],
      [77.01, 43.11],
      [77.02, 43.12],
    ],
  );
  const profile = RouteProfile(4.2, 280, 2.1, 'Лёгкий');
  final now = DateTime(2026, 9, 27, 10);

  test('unknown forecast never produces a green departure status', () {
    final result = assessTrip(
      profile: profile,
      now: now,
      turnAt: now.add(const Duration(hours: 1)),
      returnAt: now.add(const Duration(hours: 3)),
      weather: null,
      battery: 80,
      checkedItems: 7,
      totalItems: 7,
      hasContact: true,
      demo: false,
    );
    expect(result.level, 1);
    expect(result.reasons.any((reason) => reason.contains('прогноза')), true);
  });

  test('rain shower code is not classified as snow or ice', () {
    final weather = WeatherSnapshot(
      fetchedAt: now,
      routeId: 'r',
      windKmh: 10,
      rainChance: 60,
      weatherCode: 80,
    );
    expect(weather.snowOrIce, false);
  });

  test('storm and return after sunset produce a red departure status', () {
    final result = assessTrip(
      profile: profile,
      now: now,
      turnAt: now.add(const Duration(hours: 1)),
      returnAt: now.add(const Duration(hours: 9)),
      weather: WeatherSnapshot(
        fetchedAt: now,
        routeId: 'r',
        windKmh: 18,
        rainChance: 80,
        weatherCode: 95,
        sunset: now.add(const Duration(hours: 8)),
      ),
      battery: 90,
      checkedItems: 7,
      totalItems: 7,
      hasContact: true,
      demo: false,
    );
    expect(result.level, 2);
    expect(result.reasons.any((reason) => reason.contains('грозе')), true);
    expect(result.reasons.any((reason) => reason.contains('заката')), true);
  });

  test('weather parser uses Unix timestamps and six upcoming hours', () async {
    final start =
        DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000;
    final client = MockClient((request) async {
      expect(request.url.queryParameters['timeformat'], 'unixtime');
      return http.Response(
        jsonEncode({
          'hourly': {
            'time': List.generate(12, (i) => start + i * 3600),
            'weather_code': List.filled(12, 1),
            'wind_speed_10m': List.generate(12, (i) => i == 3 ? 55 : 15),
            'precipitation_probability': List.generate(
              12,
              (i) => i == 4 ? 78 : 5,
            ),
          },
          'daily': {
            'sunset': [start + 7200, start + 93600],
          },
        }),
        200,
      );
    });
    final weather = await fetchRouteWeather(route, client: client);
    expect(weather.windKmh, 55);
    expect(weather.rainChance, 78);
    expect(weather.sunset, isNotNull);
    client.close();
  });
}
