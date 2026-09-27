import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_state.dart';
import '../../core/monitoring.dart';
import '../../core/ui.dart';
import 'terrain_view.dart';
import 'monitor_panel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool safetyVisible = false, mapReady = false;
  bool monitorOpen = false;
  String? mapError, lastPlace, lastRoute;
  int lastTrack = -1, commandId = 0;
  List<Map<String, dynamic>> commands = [];
  void send(Map<String, dynamic> command) {
    if (mounted) {
      setState(
        () => commands = [
          {...command, 'nonce': ++commandId},
        ],
      );
    }
  }

  Future<void> showMonitor() async {
    if (monitorOpen) return;
    setState(() => monitorOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (_) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .80,
          child: MonitorPanel(send: send),
        ),
      );
    } finally {
      if (mounted) setState(() => monitorOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider), p = s.selected;
    final m = ref.read(monitoringProvider);
    final unread = ref.watch(monitoringProvider.select((v) => v.unread));
    final updates = <Map<String, dynamic>>[];
    if (lastPlace != p.id) {
      final initial = lastPlace == null && !s.focusMapPlace;
      s.focusMapPlace = false;
      lastPlace = p.id;
      updates.add({'type': 'select', 'id': p.id, 'overview': initial});
      updates.add({
        'type': 'droneMode',
        'mode': m.mode,
        'lon': p.lon,
        'lat': p.lat,
      });
      updates.add({'type': 'droneVisible', 'visible': m.visible});
    }
    if (lastRoute != s.route.id) {
      lastRoute = s.route.id;
      updates.add({
        'type': 'route',
        'points': s.route.points,
        'demo': s.route.demo,
      });
    }
    if (lastTrack != (s.session?.points.length ?? 0)) {
      lastTrack = s.session?.points.length ?? 0;
      updates.addAll([
        {
          'type': 'track',
          'points': s.session?.points.map((p) => p.toJson()).toList() ?? [],
        },
        {'type': 'position', 'lat': s.position?.lat, 'lon': s.position?.lon},
      ]);
    }
    if (updates.isNotEmpty) commands = updates;
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    final map = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ЖИВОЙ РЕЛЬЕФ / 3D',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 1.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'От города к вершинам',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!wide)
                IconButton.filledTonal(
                  tooltip: 'Горный дозор',
                  onPressed: showMonitor,
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.radar),
                  ),
                ),
              IconButton(
                tooltip: 'Моё положение',
                onPressed: () => attempt(context, () async {
                  if (!s.demo) await s.locate();
                  if (s.position == null) {
                    if (context.mounted) {
                      toast(context, 'Координаты пока не получены.');
                    }
                    return;
                  }
                  send({
                    'type': 'position',
                    'lat': s.position!.lat,
                    'lon': s.position!.lon,
                    'focus': true,
                  });
                }),
                icon: const Icon(Icons.my_location, size: 21),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TerrainView(
                      interactive: !monitorOpen,
                      commands: commands,
                      onMessage: (data) {
                        if (!mounted) return;
                        switch (data['type']) {
                          case 'ready':
                            setState(() => mapReady = true);
                          case 'error':
                            setState(() => mapError = data['message']);
                          case 'select':
                            s.selectPlace(data['id']);
                          case 'fleet':
                            ref.read(monitoringProvider).receive(data);
                          case 'droneSelect':
                            send({'type': 'droneFocus', 'id': data['id']});
                            if (!wide) showMonitor();
                          case 'outside':
                            toast(
                              context,
                              'Положение за пределами сохранённого участка.',
                            );
                        }
                      },
                    ),
                  ),
                  if (!mapReady && mapError == null)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (mapError != null)
                    Positioned(
                      top: 100,
                      left: 15,
                      right: 15,
                      child: Notice(
                        '3D не загрузилась: $mapError',
                        warning: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: s.places
                      .map(
                        (place) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(place.name),
                            selected: p.id == place.id,
                            onSelected: (_) => s.selectPlace(place.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      p.image,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          p.kind,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: safetyVisible
                        ? 'Скрыть слой безопасности'
                        : 'Слой безопасности: справочные объекты OSM',
                    onPressed: () {
                      setState(() => safetyVisible = !safetyVisible);
                      send({'type': 'safety', 'visible': safetyVisible});
                      if (safetyVisible) {
                        toast(
                          context,
                          'Объекты OSM справочные: их доступность сейчас не подтверждена.',
                        );
                      }
                    },
                    icon: Icon(
                      safetyVisible ? Icons.shield : Icons.shield_outlined,
                      color: forest,
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'О месте',
                    onPressed: () => context.push('/place/${p.id}'),
                    icon: const Icon(Icons.arrow_outward, size: 19),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    return wide
        ? Row(
            children: [
              Expanded(child: map),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 330,
                child: ColoredBox(
                  color: Colors.white,
                  child: MonitorPanel(send: send),
                ),
              ),
            ],
          )
        : map;
  }
}
