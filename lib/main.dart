import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/app_state.dart';
import 'core/ui.dart';
import 'l10n/app_localizations.dart';
import 'features/explore/explore_screen.dart';
import 'features/place_details/place_screen.dart';
import 'features/map/map_screen.dart';
import 'features/preparation/preparation_screen.dart';
import 'features/hike/hike_screen.dart';
import 'features/sos/sos_screen.dart';
import 'features/saved/saved_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/guide/offline_guide_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TauSafeApp()));
}

final router = GoRouter(
  initialLocation: '/explore',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          MainShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/explore', builder: (c, s) => const ExploreScreen()),
        GoRoute(path: '/map', builder: (c, s) => const MapScreen()),
        GoRoute(path: '/hike', builder: (c, s) => const HikeScreen()),
        GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),
      ],
    ),
    GoRoute(
      path: '/place/:id',
      builder: (c, s) => PlaceScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/prepare', builder: (c, s) => const PreparationScreen()),
    GoRoute(path: '/sos', builder: (c, s) => const SosScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(path: '/guide', builder: (c, s) => const OfflineGuideScreen()),
  ],
);

class TauSafeApp extends ConsumerStatefulWidget {
  const TauSafeApp({super.key});
  @override
  ConsumerState<TauSafeApp> createState() => _TauSafeAppState();
}

class _TauSafeAppState extends ConsumerState<TauSafeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) ref.read(appProvider).background();
    if (state == AppLifecycleState.resumed) {
      ref.read(appProvider).refreshBattery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    return MaterialApp.router(
      title: 'TauSafe',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        if (!state.ready) {
          return Scaffold(
            body: Center(
              child: state.error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.error!),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              state.error = null;
                              state.initialize();
                            },
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        }
        return Column(
          children: [
            if (state.storageError != null)
              SafeArea(
                bottom: false,
                child: Material(
                  child: Notice(state.storageError!, warning: true),
                ),
              ),
            Expanded(child: child!),
          ],
        );
      },
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const paths = ['/explore', '/map', '/hike', '/saved'];
    const icons = [
      Icons.explore_outlined,
      Icons.layers_outlined,
      Icons.hiking,
      Icons.bookmark_outline,
    ];
    final labels = [l.explore, l.map, l.hike, l.saved];
    final index = paths.indexOf(path).clamp(0, 3);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: child,
        ),
      ),
    );
    return Scaffold(
      body: wide
          ? Row(
              children: [
                Container(
                  width: 98,
                  color: ink,
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        const Icon(
                          Icons.terrain,
                          size: 35,
                          color: Color(0xffa5e7ee),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'TAUSAFE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 42),
                        for (var i = 0; i < paths.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            child: Material(
                              color: i == index
                                  ? const Color(0xff2b4c60)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () => context.go(paths[i]),
                                child: SizedBox(
                                  width: 80,
                                  height: 70,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        icons[i],
                                        color: i == index
                                            ? const Color(0xffa5e7ee)
                                            : const Color(0xff9ab0be),
                                        size: 23,
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        labels[i],
                                        style: TextStyle(
                                          color: i == index
                                              ? Colors.white
                                              : const Color(0xffb1c3cd),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => context.push('/settings'),
                          tooltip: 'Настройки',
                          icon: const Icon(
                            Icons.tune,
                            color: Color(0xffb1c3cd),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 72,
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(paths[i]),
              destinations: [
                for (var i = 0; i < paths.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }
}
