import 'models.dart';
import 'trip_readiness.dart';

String tripPlanMessage({
  required HikingRoute route,
  required RouteProfile profile,
  required DateTime? turnAt,
  required DateTime? returnAt,
  required bool demo,
}) {
  final start = route.points.first;
  return '${demo ? 'ДЕМО — координаты маршрута учебные.\n' : ''}'
      'План похода TauSafe\n'
      'Маршрут: ${route.name}\n'
      'Начало: ${start[1].toStringAsFixed(6)}, ${start[0].toStringAsFixed(6)}\n'
      'Длина: ${profile.distanceKm.toStringAsFixed(1)} км, набор высоты ~${profile.ascentM} м\n'
      'Примерное время в пути: ${profile.hours.toStringAsFixed(1)} ч\n'
      'Разворот: ${turnAt?.toLocal() ?? 'не указан'}\n'
      'Возвращение: ${returnAt?.toLocal() ?? 'не указано'}\n'
      'Если я не выйду на связь к назначенному времени, попробуйте связаться со мной. '
      'При признаках чрезвычайной ситуации передайте план и последние известные координаты службе 112.\n'
      'Сообщение подготовлено пользователем; TauSafe не отправляет его автоматически.';
}

String overdueMessage({
  required HikingRoute route,
  required TrackPoint? point,
  required DateTime? plannedReturn,
  required bool demo,
}) {
  final now = DateTime.now();
  final stale =
      point == null || now.difference(point.time) > const Duration(minutes: 2);
  return '${demo ? 'ДЕМО — НЕ ОТПРАВЛЯТЬ.\n' : ''}'
      'Я задерживаюсь в походе TauSafe.\n'
      'Маршрут: ${route.name}\n'
      'Планируемое возвращение: ${plannedReturn?.toLocal() ?? 'не указано'}\n'
      'Последние координаты: ${point?.coordinates ?? 'не определены'}'
      '${stale ? ' (могут быть устаревшими)' : ''}\n'
      'Время координат: ${point?.time.toLocal() ?? 'нет данных'}\n'
      'Если я не отвечаю и есть признаки опасности, обратитесь в 112.';
}
