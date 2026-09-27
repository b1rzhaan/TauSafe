import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/ui.dart';
import '../../core/trip_plan.dart';

class HikeScreen extends ConsumerWidget {
  const HikeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider), h = s.session;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                h == null ? 'Твой следующий поход' : 'На маршруте',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Помощь SOS',
              onPressed: () => context.push('/sos'),
              icon: const Icon(Icons.sos, color: Color(0xffae3434)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (h == null) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.hiking, size: 46, color: forest),
                const SizedBox(height: 20),
                Text(
                  'Сначала — немного подготовки',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Выберите маршрут, задайте время возвращения и проверьте снаряжение.',
                ),
                const SizedBox(height: 20),
                Text(
                  s.route.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/prepare'),
                  child: const Text('Подготовиться к походу'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Notice(
            'Встроенный маршрут предназначен для демонстрации. Свой GeoJSON можно добавить в разделе «Сохранённое».',
          ),
        ] else ...[
          if (h.demo)
            const Notice(
              'ДЕМО — координаты смоделированы',
              icon: Icons.science_outlined,
              warning: true,
            ),
          if (s.recovery) ...[
            const SizedBox(height: 12),
            const Notice(
              'Найден незавершённый поход. Запись на паузе. Нажмите «Продолжить», чтобы начать новый сегмент.',
            ),
          ],
          if (s.returnOverdue) ...[
            const SizedBox(height: 14),
            Panel(
              color: const Color(0xfffff1e8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Время возвращения прошло',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xffa93434),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Подтвердите своё состояние. Если задерживаетесь, сообщите близкому вручную. '
                    'Приложение не отправляет сообщения автоматически.',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: s.checkIn,
                        child: const Text(
                          'Я в безопасности · напомнить через 15 мин',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: h.demo
                            ? null
                            : () => attempt(context, () async {
                                await SharePlus.instance.share(
                                  ShareParams(
                                    text: overdueMessage(
                                      route: s.route,
                                      point: s.position,
                                      plannedReturn: s.returnAt,
                                      demo: false,
                                    ),
                                  ),
                                );
                              }),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Сообщить близкому'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/sos'),
                        child: const Text('SOS и координаты'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(s.route.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            s.active
                ? '● Запись идёт при открытом приложении'
                : 'Ⅱ Запись на паузе',
            style: const TextStyle(
              color: forest,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Wrap(
              spacing: 32,
              runSpacing: 18,
              children: [
                Metric(durationText(h.elapsedSeconds), 'время записи'),
                Metric(
                  '${(h.distance / 1000).toStringAsFixed(2)} км',
                  'пройдено по GPS',
                ),
                Metric(clockTime(s.turnAt), 'разворот'),
                Metric(
                  s.battery == null ? '—' : '${s.battery}%',
                  'заряд телефона',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: const Color(0xffe5eff5),
              height: 200,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: TrackPainter(s.route.points, h.points),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    top: 10,
                    child: Text(
                      'СХЕМА · БЕЗ КАРТОГРАФИЧЕСКОЙ ПОДЛОЖКИ',
                      style: TextStyle(fontSize: 9, color: muted),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    bottom: 10,
                    child: Text(
                      'Оранжевый — план · синий — запись',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 3,
                    child: IconButton(
                      tooltip: 'Открыть 3D-карту',
                      onPressed: () => context.go('/map'),
                      icon: const Icon(Icons.open_in_full, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (s.stale)
            const Notice(
              'Нет свежей достоверной GPS-позиции. Проверьте разрешение и обзор неба.',
              warning: true,
              icon: Icons.gps_off,
            ),
          ...s.alerts
              .take(4)
              .map(
                (a) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Notice(a, warning: true, icon: Icons.warning_amber),
                ),
              ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'МОЁ ПОЛОЖЕНИЕ',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  s.position?.coordinates ?? 'Координаты не получены',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  s.gpsStatus,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                if (s.position != null)
                  Text(
                    'Получено: ${clockTime(s.position!.time.toLocal())} · ±${s.position!.accuracy.round()} м',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                const SizedBox(height: 10),
                Text(
                  s.connection,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    attempt(context, () => s.active ? s.pause() : s.resume()),
                icon: Icon(s.active ? Icons.pause : Icons.play_arrow),
                label: Text(s.active ? 'Пауза' : 'Продолжить'),
              ),
              OutlinedButton(
                onPressed: () => attempt(context, () async {
                  if (await confirm(
                    context,
                    'Завершить поход?',
                    'Записанные точки и длительность останутся в истории.',
                    action: 'Завершить',
                  )) {
                    await s.finish();
                  }
                }),
                child: const Text('Завершить'),
              ),
            ],
          ),
          if (h.demo) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                if (!s.active) {
                  toast(context, 'Сначала продолжите демонстрацию.');
                  return;
                }
                s.demoSource?.offRoute = !(s.demoSource?.offRoute ?? false);
                s.changed();
              },
              icon: const Icon(Icons.alt_route),
              label: Text(
                s.demoSource?.offRoute == true
                    ? 'Вернуться к линии'
                    : 'Имитировать отклонение',
              ),
            ),
            const Text(
              'Предупреждение появится после трёх последовательных точек вне порога (около 6 секунд).',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffa93434),
          ),
          onPressed: () => context.push('/sos'),
          icon: const Icon(Icons.sos),
          label: const Text('Помощь · SOS'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/guide'),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Офлайн-памятка'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Фоновое отслеживание не включено. При сворачивании приложения запись приостанавливается.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

class TrackPainter extends CustomPainter {
  TrackPainter(this.route, this.points);
  final List<List<double>> route;
  final List<TrackPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    if (route.isEmpty) return;
    final all = [
      ...route,
      ...points.map((p) => [p.lon, p.lat]),
    ];
    double minX = all.first[0], maxX = minX, minY = all.first[1], maxY = minY;
    for (final p in all) {
      minX = math.min(minX, p[0]);
      maxX = math.max(maxX, p[0]);
      minY = math.min(minY, p[1]);
      maxY = math.max(maxY, p[1]);
    }
    final dx = math.max((maxX - minX) * .73, .0001),
        dy = math.max(maxY - minY, .0001),
        scale = math.min((size.width - 50) / dx, (size.height - 70) / dy);
    Offset xy(double lon, double lat) => Offset(
      size.width / 2 + (lon - (minX + maxX) / 2) * .73 * scale,
      size.height / 2 - (lat - (minY + maxY) / 2) * scale,
    );
    final grid = Paint()
      ..color = const Color(0xffd6e4ec)
      ..strokeWidth = .6;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final p = Path()
      ..moveTo(
        xy(route.first[0], route.first[1]).dx,
        xy(route.first[0], route.first[1]).dy,
      );
    for (final a in route.skip(1)) {
      p.lineTo(xy(a[0], a[1]).dx, xy(a[0], a[1]).dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0xffd89b3e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (a.segment == b.segment) {
        canvas.drawLine(
          xy(a.lon, a.lat),
          xy(b.lon, b.lat),
          Paint()
            ..color = const Color(0xff3487b5)
            ..strokeWidth = 3,
        );
      }
    }
    if (points.isNotEmpty) {
      canvas.drawCircle(
        xy(points.last.lon, points.last.lat),
        6,
        Paint()..color = const Color(0xff167abe),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrackPainter oldDelegate) => true;
}
