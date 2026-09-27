import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/ui.dart';

class ReadinessPanel extends StatelessWidget {
  const ReadinessPanel({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final weather = state.routeWeather;
    final readiness = state.readiness;
    final color = switch (readiness.level) {
      2 => const Color(0xffa93434),
      1 => amber,
      _ => forest,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Безопасный старт'),
        Panel(
          color: Color.lerp(Colors.white, color, .055)!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    readiness.level == 2
                        ? Icons.warning_amber_rounded
                        : readiness.level == 1
                        ? Icons.fact_check_outlined
                        : Icons.check_circle_outline,
                    color: color,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      readiness.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${profile.level} маршрут · ${profile.distanceKm.toStringAsFixed(1)} км · '
                'набор ~${profile.ascentM} м · ~${profile.hours.toStringAsFixed(1)} ч',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              ...readiness.reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '• $reason',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                weather == null
                    ? 'Прогноз не загружен. Карта и памятка доступны без интернета.'
                    : 'Open-Meteo · обновлено ${weather.fetchedAt.toLocal()} · '
                          'ветер до ${weather.windKmh.round()} км/ч · осадки до ${weather.rainChance}%'
                          '${weather.freshAt(DateTime.now()) ? '' : ' · УСТАРЕЛО'}',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              if (state.weatherError != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.weatherError!,
                  style: const TextStyle(fontSize: 11, color: amber),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.weatherLoading ? null : state.updateWeather,
                icon: state.weatherLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  state.weatherLoading
                      ? 'Обновляем прогноз'
                      : 'Обновить прогноз',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Оценка ориентировочная: модель рельефа и точечный прогноз '
                'не учитывают все условия на тропе. При сомнении отложите выход.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
