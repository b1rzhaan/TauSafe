import 'dart:math' as math;
import 'models.dart';

double distanceToSegment(TrackPoint p, List<double> a, List<double> b) {
  final scale = math.cos(p.lat * math.pi / 180) * 111195;
  final ax = (a[0] - p.lon) * scale,
      ay = (a[1] - p.lat) * 111195,
      bx = (b[0] - p.lon) * scale,
      by = (b[1] - p.lat) * 111195;
  final dx = bx - ax, dy = by - ay, den = dx * dx + dy * dy;
  final t = den == 0 ? 0.0 : (-(ax * dx + ay * dy) / den).clamp(0.0, 1.0);
  return math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2));
}

class SafetyEngine {
  SafetyEngine({
    this.threshold = 70,
    this.resetThreshold = 35,
    this.consecutive = 3,
    this.cooldown = const Duration(minutes: 2),
    this.maxAccuracy = 50,
  });
  final double threshold, resetThreshold, maxAccuracy;
  final int consecutive;
  final Duration cooldown;
  int _outside = 0;
  bool _warned = false;
  DateTime? _lastWarning;
  DateTime? _lastPoint;
  bool update(TrackPoint point, List<List<double>> route, DateTime now) {
    if (point.accuracy > maxAccuracy ||
        now.difference(point.time) > const Duration(seconds: 30) ||
        point.time.isAfter(now.add(const Duration(seconds: 5))) ||
        route.length < 2) {
      _outside = 0;
      return false;
    }
    if (_lastPoint != null && !point.time.isAfter(_lastPoint!)) return false;
    if (_lastPoint != null &&
        point.time.difference(_lastPoint!) > const Duration(seconds: 30)) {
      _outside = 0;
    }
    _lastPoint = point.time;
    double distance = double.infinity;
    for (int i = 1; i < route.length; i++) {
      distance = math.min(
        distance,
        distanceToSegment(point, route[i - 1], route[i]),
      );
    }
    final certainDistance = math.max(0, distance - point.accuracy);
    if (certainDistance < resetThreshold) {
      _outside = 0;
      _warned = false;
      return false;
    }
    if (certainDistance <= threshold) {
      _outside = 0;
      return false;
    }
    _outside++;
    if (_outside >= consecutive &&
        !_warned &&
        (_lastWarning == null || now.difference(_lastWarning!) >= cooldown)) {
      _warned = true;
      _lastWarning = now;
      return true;
    }
    return false;
  }
}

String sosMessage({
  required String route,
  required TrackPoint? point,
  required DateTime now,
  String description = '',
  bool demo = false,
}) {
  final valid = point != null && point.demo == demo ? point : null;
  final stale =
      valid != null && now.difference(valid.time) > const Duration(minutes: 2);
  return '${demo ? 'ДЕМО — НЕ ОТПРАВЛЯТЬ. Координаты смоделированы.\n' : ''}Мне нужна помощь.\nМаршрут: $route\nКоординаты: ${valid?.coordinates ?? 'не определены'}${stale ? ' (УСТАРЕЛИ)' : ''}\nВремя определения: ${valid?.time.toLocal().toIso8601String() ?? 'нет'}\nТочность: ${valid == null ? 'нет' : '±${valid.accuracy.round()} м'}\nОписание: ${description.isEmpty ? 'не указано' : description}';
}
