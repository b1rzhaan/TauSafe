import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_state.dart';
import '../../core/ui.dart';

class PlaceScreen extends ConsumerWidget {
  const PlaceScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final place = s.places.where((p) => p.id == id).firstOrNull;
    if (place == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Место не найдено')),
      );
    }
    final story = place.story;
    final moments = (story['moments'] as List).cast<Map<String, dynamic>>();
    final gallery = place.gallery;
    final routes = s.routes.where((r) => r.placeId == id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(place.kind),
        actions: [
          IconButton(
            tooltip: 'Избранное',
            onPressed: () => s.favorite(id),
            icon: Icon(
              s.favorites.contains(id) ? Icons.favorite : Icons.favorite_border,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
            children: [
              _PlaceGallery(gallery: gallery),
              const SizedBox(height: 22),
              Text(
                'ЗАИЛИЙСКИЙ АЛАТАУ · ${place.kind.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.7,
                  color: muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                place.name,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(
                story['tagline'] as String,
                style: const TextStyle(
                  color: forest,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                story['lead'] as String,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  s.selectPlace(id);
                  s.focusMapPlace = true;
                  context.go('/map');
                },
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Посмотреть в 3D'),
              ),
              SectionTitle(
                'Что здесь интересно',
                trailing: Text(
                  '${moments.length} причины посмотреть',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 610;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: moments
                        .map(
                          (moment) => SizedBox(
                            width: wide
                                ? (constraints.maxWidth - 20) / 3
                                : constraints.maxWidth,
                            child: _MomentCard(moment: moment),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SectionTitle('Перед поездкой'),
              Notice(story['visitNote'] as String, warning: true),
              TextButton.icon(
                onPressed: () => openUrl(context, Uri.parse(story['source'])),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Проверить у первоисточника'),
              ),
              const SectionTitle('О месте'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тип: ${place.kind}'),
                    const SizedBox(height: 8),
                    Text(
                      'Высота: ${place.data['altitude'] ?? 'нет подтверждённых данных'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Координаты: ${place.lat == null ? 'нет подтверждённых данных' : '${place.lat!.toStringAsFixed(6)}, ${place.lon!.toStringAsFixed(6)}'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      place.data['coordinateNote'] ??
                          'Положение объекта справочное, не точка начала тропы.',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Как добраться'),
              const Text(
                'До объекта можно открыть внешний навигатор. Для пешего похода нужна отдельная геометрия тропы и подтверждённая точка старта.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  if (place.lat == null) {
                    toast(
                      context,
                      'Координаты этого места ещё не подтверждены.',
                    );
                    return;
                  }
                  openUrl(
                    context,
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': '${place.lat},${place.lon}',
                    }),
                  );
                },
                icon: const Icon(Icons.directions_outlined),
                label: Text(
                  place.data['coordinateNote'] != null
                      ? 'Открыть точку съёмки'
                      : 'Открыть объект в навигаторе',
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (place.lat == null) {
                    toast(context, 'Нет подтверждённых координат.');
                    return;
                  }
                  Clipboard.setData(
                    ClipboardData(text: '${place.lat}, ${place.lon}'),
                  );
                  toast(context, 'Координаты скопированы');
                },
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('Скопировать координаты'),
              ),
              const SectionTitle('Пешие маршруты'),
              if (routes.isEmpty)
                const Notice(
                  'Подтверждённых треков пока нет. Можно импортировать свой GeoJSON в разделе «Сохранённое».',
                ),
              ...routes.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tag(r.demo ? 'ДЕМО-МАРШРУТ' : 'ИМПОРТ · НЕ ПРОВЕРЕН'),
                        const SizedBox(height: 12),
                        Text(
                          r.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(r.distance / 1000).toStringAsFixed(1)} км · длина ${r.demo ? 'синтетической' : 'импортированной'} линии',
                        ),
                        const Text(
                          'Набор высоты, сложность и время: нет подтверждённых данных.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          r.source,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () {
                                if (s.session != null &&
                                    s.session!.routeId != r.id) {
                                  toast(
                                    context,
                                    'Сначала завершите текущий поход.',
                                  );
                                  return;
                                }
                                s.selectRoute(r.id);
                                if (r.demo) s.setDemo(true);
                                context.push('/prepare');
                              },
                              child: const Text('Подготовиться'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                s.saveRoute(r.id);
                                toast(
                                  context,
                                  'Карточка и линия маршрута сохранены',
                                );
                              },
                              icon: Icon(
                                s.saved.contains(r.id)
                                    ? Icons.bookmark
                                    : Icons.bookmark_outline,
                              ),
                              label: const Text('Сохранить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SectionTitle('Сезон и ограничения'),
              const Notice(
                'Актуальный статус открытия не подтверждён. Проверьте условия у администрации территории. Снег, лёд и осадки меняют состояние подходов.',
                warning: true,
              ),
              const SectionTitle('Источники'),
              Text(
                'Сведения просмотрены: ${place.data['checked']}. Это не подтверждение доступности сегодня.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              TextButton(
                onPressed: () => openUrl(context, Uri.parse(place.source)),
                child: const Text('Открыть источник описания'),
              ),
              if (place.lat != null)
                TextButton(
                  onPressed: () => openUrl(
                    context,
                    Uri.parse(place.data['coordinateSource']),
                  ),
                  child: const Text('Источник справочных координат'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceGallery extends StatelessWidget {
  const _PlaceGallery({required this.gallery});
  final List<Map<String, dynamic>> gallery;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 550;
          if (wide) {
            return SizedBox(
              height: 310,
              child: Row(
                children: [
                  Expanded(flex: 3, child: _PhotoTile(item: gallery.first)),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _PhotoTile(item: gallery.last)),
                ],
              ),
            );
          }
          return Column(
            children: [
              SizedBox(height: 235, child: _PhotoTile(item: gallery.first)),
              const SizedBox(height: 8),
              SizedBox(height: 122, child: _PhotoTile(item: gallery.last)),
            ],
          );
        },
      ),
      const SizedBox(height: 7),
      ...gallery.map((item) {
        final photo = item['photo'] as Map<String, dynamic>;
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => openUrl(context, Uri.parse(photo['page'])),
            icon: const Icon(Icons.open_in_new, size: 13),
            label: Text(
              'Фото: ${photo['author']} · ${photo['license']}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        );
      }),
    ],
  );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => Material(
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        final photo = item['photo'] as Map<String, dynamic>;
        openUrl(context, Uri.parse(photo['page']));
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            item['image'] as String,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xffdceaf1),
              child: Center(child: Icon(Icons.landscape_outlined, size: 44)),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xb5001711)],
                stops: [0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 15,
            right: 15,
            bottom: 13,
            child: Text(
              item['caption'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});
  final Map<String, dynamic> moment;

  @override
  Widget build(BuildContext context) => Panel(
    color: const Color(0xffeaf2f7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 3,
          decoration: BoxDecoration(
            color: forest,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 13),
        Text(
          moment['title'] as String,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          moment['text'] as String,
          style: const TextStyle(fontSize: 12, color: muted, height: 1.45),
        ),
      ],
    ),
  );
}
