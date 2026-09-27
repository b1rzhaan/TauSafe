import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_state.dart';
import '../../core/ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SectionTitle('Предупреждения во время похода'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: s.signalsEnabled,
                onChanged: (value) => s.setSignals(vibration: value),
                title: const Text('Вибросигнал'),
                subtitle: const Text(
                  'Отклонение от маршрута, время разворота и возвращения, низкий заряд',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: s.voiceEnabled,
                onChanged: (value) => s.setSignals(voice: value),
                title: const Text('Голосовые подсказки'),
                subtitle: const Text('Произносить важные предупреждения вслух'),
              ),
              const Text(
                'Сигналы работают, пока приложение открыто и поход активен; '
                'телефон может не воспроизвести звук в беззвучном режиме.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: s.demo,
                onChanged: s.session == null ? s.setDemo : null,
                title: const Text('Демонстрационный режим'),
                subtitle: Text(
                  s.session != null
                      ? 'Завершите поход для смены режима.'
                      : 'Виртуальные координаты. SOS только в предпросмотре.',
                ),
              ),
              const SectionTitle('Контакт близкого'),
              TextFormField(
                initialValue: s.contact,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон (необязательно)',
                ),
                onChanged: (v) {
                  s.contact = v;
                  s.changed();
                },
              ),
              const SectionTitle('Предупреждения'),
              Text(
                'Порог отклонения: ${s.deviationThreshold.round()} м',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: s.deviationThreshold,
                min: 50,
                max: 150,
                divisions: 10,
                label: '${s.deviationThreshold.round()} м',
                onChanged: s.setThreshold,
              ),
              const Text(
                'Учитываем точность GPS и три последовательные точки. Возврат в коридор: 35 м. Пауза между предупреждениями: 2 минуты.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Notice(
                'Пороги — параметры алгоритма MVP, а не подтверждённый стандарт безопасности.',
                warning: true,
              ),
              const SectionTitle('Геолокация'),
              Text(s.gpsStatus),
              TextButton.icon(
                onPressed: () => attempt(context, () async {
                  final p = await Geolocator.checkPermission();
                  final enabled = await Geolocator.isLocationServiceEnabled();
                  if (context.mounted) {
                    toast(
                      context,
                      'Разрешение: ${p.name}. Геолокация ${enabled ? 'включена' : 'отключена'}.',
                    );
                  }
                }),
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Проверить доступ к GPS'),
              ),
              TextButton(
                onPressed: () => attempt(context, () async {
                  if (!await Geolocator.openAppSettings() && context.mounted) {
                    toast(context, 'Откройте настройки приложения вручную.');
                  }
                }),
                child: const Text('Настройки разрешений'),
              ),
              const SectionTitle('О TauSafe'),
              const Text(
                'MVP для Mountain Safe\nРусский интерфейс · Android\nБез регистрации. Пользовательские данные хранятся локально.',
              ),
              const SizedBox(height: 12),
              const Notice(
                'Рельеф географический, с художественным освещением и увеличением высот ×1,65. Линия встроенного маршрута синтетическая. Приложение не определяет безопасность тропы.',
              ),
              TextButton(
                onPressed: () => openUrl(
                  context,
                  Uri.parse('https://registry.opendata.aws/terrain-tiles/'),
                ),
                child: const Text('Источник высот · Terrain Tiles'),
              ),
              TextButton(
                onPressed: () => openUrl(
                  context,
                  Uri.parse(
                    'https://github.com/tilezen/joerd/blob/master/docs/attribution.md',
                  ),
                ),
                child: const Text('Атрибуция данных высот'),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'TauSafe',
                  applicationVersion: '1.0.0 MVP',
                ),
                child: const Text('Лицензии библиотек'),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => attempt(context, () async {
                  if (await confirm(
                    context,
                    'Удалить пользовательские данные?',
                    'Будут удалены избранное, импортированные треки, чек-лист, контакт и история. Текущий поход завершится без сохранения. Встроенный каталог останется.',
                    action: 'Удалить',
                  )) {
                    await s.clearData();
                    if (context.mounted) {
                      toast(context, 'Пользовательские данные удалены');
                    }
                  }
                }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить пользовательские данные'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
