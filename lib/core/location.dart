import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'models.dart';

abstract class LocationSource {
  Stream<TrackPoint> positions();
}

class GpsSource implements LocationSource {
  static Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'Геолокация отключена. Включите её в настройках телефона.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('Доступ к GPS запрещён в настройках приложения.');
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Без разрешения на GPS запись координат недоступна.');
    }
  }

  @override
  Stream<TrackPoint> positions() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).map(
        (p) => TrackPoint(
          p.latitude,
          p.longitude,
          p.timestamp,
          accuracy: p.accuracy,
        ),
      );
  static Future<TrackPoint> current() async {
    await ensurePermission();
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return TrackPoint(
      p.latitude,
      p.longitude,
      p.timestamp,
      accuracy: p.accuracy,
    );
  }
}

class DemoSource implements LocationSource {
  DemoSource(this.route);
  final HikingRoute route;
  int index = 0;
  bool offRoute = false;
  @override
  Stream<TrackPoint> positions() =>
      Stream.periodic(const Duration(seconds: 2), (_) {
        final progress = (index++ % 120) / 119 * (route.points.length - 1),
            i = progress.floor(),
            j = (i + 1).clamp(0, route.points.length - 1),
            f = progress - i;
        final a = route.points[i], b = route.points[j];
        return TrackPoint(
          a[1] + (b[1] - a[1]) * f + (offRoute ? 0.002 : 0),
          a[0] + (b[0] - a[0]) * f,
          DateTime.now(),
          demo: true,
        );
      });
}
