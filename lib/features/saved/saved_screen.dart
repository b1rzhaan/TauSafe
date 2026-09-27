import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_state.dart';
import '../../core/ui.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Всегда под рукой',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'Твои места, маршруты и пройденный путь.',
          style: TextStyle(color: muted),
        ),
        const SectionTitle('Офлайн-пакет'),
        const Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.offline_pin, color: forest),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Алматы · участок 3D-рельефа',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Модель высот и фотографии включены в приложение. Для просмотра этого участка интернет не требуется.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 8),
              Text(
                'Топографическая подложка: не скачана. Другие области: не загружены. Встроенный пакет удаляется вместе с приложением.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        const SectionTitle('Сохранённые маршруты'),
        if (s.saved.isEmpty)
          const Notice(
            'Здесь появятся маршруты, сохранённые в карточке места или перед походом.',
          ),
        ...s.routes
            .where((r) => s.saved.contains(r.id))
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tag(r.demo ? 'ДЕМО' : 'ИМПОРТ · НЕ ПРОВЕРЕН'),
                      const SizedBox(height: 8),
                      Text(
                        r.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${(r.distance / 1000).toStringAsFixed(1)} км по линии · геометрия сохранена',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {
                              if (s.session != null &&
                                  s.session!.routeId != r.id) {
                                toast(
                                  context,
                                  'Завершите текущий поход перед выбором другого маршрута.',
                                );
                                return;
                              }
                              s.selectRoute(r.id);
                              if (r.demo) s.setDemo(true);
                              context.push('/prepare');
                            },
                            child: const Text('Открыть'),
                          ),
                          TextButton(
                            onPressed: () {
                              s.saved.remove(r.id);
                              s.changed();
                            },
                            child: const Text('Убрать из сохранённого'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        OutlinedButton.icon(
          onPressed: () => attempt(context, () async {
            if (s.session != null) {
              throw StateError('Завершите текущий поход перед импортом.');
            }
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['json', 'geojson'],
            );
            if (result.isEmpty) return;
            final file = result.single;
            if ((await file.length() ?? 5000001) > 5000000) {
              throw const FormatException('Файл должен быть меньше 5 МБ');
            }
            final bytes = await file.readAsBytes();
            final json = jsonDecode(utf8.decode(bytes));
            if (json is! Map<String, dynamic>) {
              throw const FormatException('Ожидается GeoJSON');
            }
            await s.importRoute(json);
            if (context.mounted) {
              toast(context, 'Трек импортирован. Статус: не проверен.');
            }
          }),
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Импортировать GeoJSON'),
        ),
        const SectionTitle('Избранные места'),
        if (s.favorites.isEmpty)
          const Notice(
            'Нажмите на сердечко в каталоге, чтобы сохранить место.',
          ),
        ...s.places
            .where((p) => s.favorites.contains(p.id))
            .map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.landscape, color: forest),
                title: Text(p.name),
                subtitle: Text(p.kind),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/place/${p.id}'),
              ),
            ),
        const SectionTitle('История походов'),
        if (s.history.isEmpty)
          const Notice('После завершения похода запись появится здесь.'),
        ...s.history.map(
          (h) => ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${h.demo ? 'ДЕМО · ' : 'GPS · '}${s.routes.where((r) => r.id == h.routeId).firstOrNull?.name ?? 'Маршрут'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${h.started.toLocal().toString().substring(0, 16)} · ${(h.distance / 1000).toStringAsFixed(2)} км',
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Время записи: ${durationText(h.elapsedSeconds)}\nТочек: ${h.points.length}\nИсточник: ${h.demo ? 'симуляция' : 'GPS'}',
                  style: const TextStyle(color: muted),
                ),
              ),
              if (h.points.isNotEmpty)
                SelectableText('Последняя точка: ${h.points.last.coordinates}'),
              TextButton(
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Удалить эту запись?',
                    'Восстановить её после удаления будет нельзя.',
                    action: 'Удалить',
                  )) {
                    s.history.removeWhere((a) => a.id == h.id);
                    s.changed();
                  }
                },
                child: const Text('Удалить запись'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
