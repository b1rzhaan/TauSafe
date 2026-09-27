import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../../core/monitoring.dart';
import '../../core/ui.dart';

class MonitorPanel extends ConsumerWidget {
  const MonitorPanel({super.key, required this.send});
  final ValueChanged<Map<String, dynamic>> send;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(monitoringProvider),
        place = ref.watch(appProvider).selected;
    void setMode(String mode) {
      m.setMode(mode);
      send({
        'type': 'droneMode',
        'mode': mode,
        'lon': place.lon,
        'lat': place.lat,
      });
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Icons.radar, color: forest, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Горный дозор',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Tag('ДЕМО'),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Три виртуальных дрона над регионом',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'patrol',
              label: Text('Обзор'),
              icon: Icon(Icons.radar, size: 16),
            ),
            ButtonSegment(
              value: 'search',
              label: Text('Поиск'),
              icon: Icon(Icons.person_search_outlined, size: 16),
            ),
          ],
          selected: {m.mode},
          onSelectionChanged: (v) => setMode(v.first),
          showSelectedIcon: false,
          style: const ButtonStyle(
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          m.mode == 'search'
              ? 'Учебный поиск · ${place.name}'
              : 'Патрулирование ущелий · демо',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        if (m.mode == 'search')
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text(
              'Полёт по секторам вокруг выбранного места. Реальные службы не вызываются.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: const Color(0xfff1f6f9),
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => send({'type': 'droneFocus', 'id': i}),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: [
                            const Color(0xffd2f0f5),
                            const Color(0xffffedd2),
                            const Color(0xffe7e4fb),
                          ][i],
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.airplanemode_active,
                          size: 19,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TAU / 0${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              m.visible
                                  ? (m.mode == 'search'
                                        ? 'Поиск по сектору'
                                        : [
                                            'Медеу',
                                            'Шымбулак',
                                            'Кок-Жайляу',
                                          ][i])
                                  : 'Слой скрыт',
                              style: const TextStyle(
                                fontSize: 10,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        m.fleet.length > i ? '${m.fleet[i]['battery']}%' : '—',
                        style: const TextStyle(
                          fontSize: 12,
                          color: forest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Дроны на карте', style: TextStyle(fontSize: 12)),
          value: m.visible,
          onChanged: (v) {
            m.setVisible(v);
            send({'type': 'droneVisible', 'visible': v});
          },
        ),
        const Divider(height: 28),
        Row(
          children: [
            const Text(
              'Лента наблюдений',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Tag('${m.unread}'),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            m.simulate(place.name, place.lon!, place.lat!);
            send({'type': 'alertMark', 'lon': place.lon, 'lat': place.lat});
          },
          icon: const Icon(Icons.auto_awesome_outlined, size: 17),
          label: const Text('Показать демо-событие'),
        ),
        if (m.events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Здесь появятся изменения и отметки для проверки. Запустите демо или сравните два кадра через AI.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        for (final event in m.events.take(5))
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: event.read
                  ? const Color(0xfff1f5f8)
                  : const Color(0xfffff4e4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.demo ? 'ДЕМО' : 'AI · ЗАГРУЖЕННЫЕ КАДРЫ'}  /  ${clockTime(event.time)}',
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: .7,
                    color: amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  event.detail,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                Text(
                  event.place,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => send({
                        'type': 'alertFocus',
                        'lon': event.lon,
                        'lat': event.lat,
                      }),
                      child: const Text('На карте'),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Отметить прочитанным',
                      onPressed: event.read ? null : () => m.acknowledge(event),
                      icon: Icon(
                        event.read ? Icons.done_all : Icons.check,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Divider(height: 30),
        const Text(
          'AI · сравнение кадров',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(m.aiStatus, style: const TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: m.aiReady && !m.analyzing
              ? () => attempt(context, () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                  );
                  if (result.isEmpty) return;
                  if (result.length != 2) {
                    throw StateError('Выберите два кадра: до и после.');
                  }
                  final encoded = <String>[];
                  for (final file in result) {
                    final length = await file.length();
                    if (length == null || length > 4 * 1024 * 1024) {
                      throw StateError(
                        'Каждый кадр должен быть не больше 4 МБ.',
                      );
                    }
                    final bytes = await file.readAsBytes();
                    final ext = file.extension?.toLowerCase();
                    encoded.add(
                      'data:image/${ext == 'jpg' ? 'jpeg' : ext};base64,${base64Encode(bytes)}',
                    );
                  }
                  if (!context.mounted) return;
                  final ok = await confirm(
                    context,
                    'Сравнить в AI?',
                    'Первый кадр (до): ${result[0].name}\nВторой кадр (после): ${result[1].name}\n\nОба изображения будут отправлены в OpenAI через сервер. Место: ${place.name}.',
                    action: 'Отправить в AI',
                  );
                  if (!ok) return;
                  await m.compareFrames(
                    before: encoded[0],
                    after: encoded[1],
                    place: place.name,
                    lon: place.lon!,
                    lat: place.lat!,
                  );
                  send({
                    'type': 'alertMark',
                    'lon': place.lon,
                    'lat': place.lat,
                  });
                })
              : null,
          icon: Icon(
            m.analyzing ? Icons.hourglass_top : Icons.compare,
            size: 17,
          ),
          label: Text(m.analyzing ? 'AI сравнивает…' : 'Выбрать 2 кадра'),
        ),
        if (!m.aiReady)
          TextButton(
            onPressed: m.checkAi,
            child: const Text('Проверить подключение'),
          ),
        const SizedBox(height: 12),
        const Text(
          'Полёты и заряд условные. Демо-события заданы сценарием, а не AI. Реальные дроны и видеопоток пока не подключены.',
          style: TextStyle(fontSize: 10, height: 1.5, color: muted),
        ),
      ],
    );
  }
}
