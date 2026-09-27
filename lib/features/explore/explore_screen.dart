import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/ui.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String query = '', filter = 'Все';
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final places = s.places
        .where(
          (p) =>
              (filter == 'Все' || p.kind == filter) &&
              p.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final compact = MediaQuery.sizeOf(context).width < 650;
    return ListView(
      padding: EdgeInsets.all(compact ? 18 : 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAUSAFE  /  ALMATY',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Выше города.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => context.push('/settings'),
              tooltip: 'Настройки',
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: compact ? 340 : 310,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/kok_ridge.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(.4, -.2),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xf511293b),
                        Color(0x8811293b),
                        Color(0x1511293b),
                      ],
                      stops: [0, .55, 1],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 23 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ТВОЙ СЛЕД. ТВОЯ ВЫСОТА.',
                        style: TextStyle(
                          color: Color(0xff9bdeed),
                          letterSpacing: 2,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Горы ближе,\nчем кажется.',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: Colors.white,
                          fontSize: compact ? 37 : 46,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Найди своё место. Подготовься к пути.',
                        style: TextStyle(
                          color: Color(0xffd8e6ee),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffa5e7ee),
                          foregroundColor: ink,
                        ),
                        onPressed: () => context.go('/map'),
                        icon: const Icon(Icons.explore_outlined, size: 18),
                        label: const Text('Открыть 3D-регион'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 22,
          runSpacing: 8,
          children: [
            _fact(Icons.terrain, '05 мест для открытия'),
            _fact(Icons.view_in_ar_outlined, '21 × 27 км в объёме'),
            _fact(Icons.wifi_off_outlined, 'Каталог доступен офлайн'),
          ],
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => context.go('/map'),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xffe1edf3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.radar, size: 28, color: forest),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Взгляд с высоты',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '3 дрона · наблюдение и поиск · демо',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_outward, size: 20),
              ],
            ),
          ),
        ),
        if (s.recovery) ...[
          const SizedBox(height: 16),
          const Notice('У вас есть незавершённый поход.', warning: true),
          TextButton(
            onPressed: () => context.go('/hike'),
            child: const Text('Продолжить поход'),
          ),
        ],
        SectionTitle(
          'Места, ради которых стоит выйти',
          trailing: compact
              ? null
              : Text(
                  '${s.places.length} направлений',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
        ),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Озеро, ущелье или любимая вершина…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Все', ...s.places.map((p) => p.kind).toSet()]
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: filter == f,
                      onSelected: (_) => setState(() => filter = f),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        if (places.isEmpty)
          const Panel(
            child: Text('Ничего не найдено. Попробуйте другое название.'),
          ),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth > 850
                ? 3
                : c.maxWidth > 550
                ? 2
                : 1;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: places
                  .map(
                    (p) => SizedBox(
                      width: (c.maxWidth - (columns - 1) * 18) / columns,
                      child: PlaceCard(
                        place: p,
                        favorite: s.favorites.contains(p.id),
                        onFavorite: () => s.favorite(p.id),
                        onTap: () => context.push('/place/${p.id}'),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        const Notice(
          'Погода и доступность маршрутов меняются. Проверьте условия перед выходом.',
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }

  Widget _fact(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: forest),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  );
}

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });
  final Place place;
  final bool favorite;
  final VoidCallback onFavorite, onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Открыть ${place.name}',
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 342,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffdbe5ec)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
                child: SizedBox(
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PlacePhoto(place: place),
                      Positioned(left: 12, top: 12, child: Tag(place.kind)),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ink,
                          ),
                          tooltip: favorite
                              ? 'Убрать из избранного'
                              : 'В избранное',
                          onPressed: onFavorite,
                          icon: Icon(
                            favorite ? Icons.favorite : Icons.favorite_border,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        place.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            '${place.gallery.length} фото · О месте',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: forest,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_outward,
                            size: 18,
                            color: forest,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PlacePhoto extends StatelessWidget {
  const PlacePhoto({super.key, required this.place});
  final Place place;
  Widget _fallback() => Container(
    color: const Color(0xffdceaf1),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.landscape_outlined, size: 40, color: forest),
          SizedBox(height: 8),
          Text(
            'Фотография недоступна',
            style: TextStyle(fontSize: 11, color: forest),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => place.image.isEmpty
      ? _fallback()
      : Image.asset(
          place.image,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        );
}
