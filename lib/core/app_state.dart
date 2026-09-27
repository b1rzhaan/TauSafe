import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models.dart';
import 'storage.dart';
import 'safety.dart';
import 'location.dart';
import 'trip_readiness.dart';
import 'weather_service.dart';

final appProvider = ChangeNotifierProvider<AppState>(
  (ref) => AppState(DeviceStore())..initialize(),
);

class AppState extends ChangeNotifier {
  AppState(this.store);
  final LocalStore store;
  bool ready = false, demo = true, recovery = false;
  String? error, storageError;
  List<Place> places = [];
  List<HikingRoute> routes = [];
  Set<String> favorites = {}, saved = {};
  Set<int> checklist = {};
  Map<String, dynamic> terrain = {};
  WeatherSnapshot? weather;
  bool weatherLoading = false, signalsEnabled = true, voiceEnabled = false;
  String? weatherError;
  DateTime? nextCheckInAt;
  DateTime? _lastReturnAlertAt;
  final FlutterTts _tts = FlutterTts();
  String selectedPlace = 'kok', contact = '';
  bool focusMapPlace = false;
  String routeId = 'demo-kok';
  DateTime? turnAt, returnAt;
  HikeSession? session;
  List<HikeSession> history = [];
  TrackPoint? realPosition, demoPosition;
  int? battery;
  String connection = 'Проверка подключения';
  String gpsStatus = 'Координаты ещё не получены';
  List<String> alerts = [];
  double deviationThreshold = 70;
  SafetyEngine safety = SafetyEngine();
  StreamSubscription<TrackPoint>? _gps;
  StreamSubscription<List<ConnectivityResult>>? _network;
  Timer? _timer;
  DemoSource? demoSource;
  int _segment = 0;
  int _tick = 0;
  int _elapsedRemainderMs = 0;
  DateTime? _lastTick;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  HikingRoute get route => routes.firstWhere(
    (r) => r.id == (session?.routeId ?? routeId),
    orElse: () => routes.first,
  );
  TrackPoint? get position => demo ? demoPosition : realPosition;
  bool get active => session?.status == 'active';
  RouteProfile get profile => RouteProfile.fromRoute(route, terrain);
  WeatherSnapshot? get routeWeather =>
      weather?.routeId == route.id ? weather : null;
  Readiness get readiness => assessTrip(
    profile: profile,
    now: DateTime.now(),
    turnAt: turnAt,
    returnAt: returnAt,
    weather: routeWeather,
    battery: battery,
    checkedItems: checklist.length,
    totalItems: checklistItems.length,
    hasContact: contact.trim().isNotEmpty,
    demo: demo || route.demo,
  );
  bool get returnOverdue =>
      session != null &&
      returnAt != null &&
      !DateTime.now().isBefore(returnAt!) &&
      (nextCheckInAt == null || !DateTime.now().isBefore(nextCheckInAt!));
  Place get selected => places.firstWhere(
    (p) => p.id == selectedPlace,
    orElse: () => places.first,
  );

  Future<void> initialize() async {
    try {
      await store.open();
      places =
          (jsonDecode(
                    await rootBundle.loadString(
                      'assets/data/places_292f8e9d1e.json',
                    ),
                  )
                  as List)
              .map((p) => Place(Map<String, dynamic>.from(p)))
              .toList();
      final demoJson =
          jsonDecode(await rootBundle.loadString('assets/data/demo_route.json'))
              as Map<String, dynamic>;
      routes = [HikingRoute.fromJson(demoJson)];
      terrain =
          jsonDecode(await rootBundle.loadString('assets/terrain/almaty.json'))
              as Map<String, dynamic>;
      await store.write('catalog', {
        'version': 1,
        'places': places.map((p) => p.data).toList(),
      });
      final state = await store.read('user');
      if (state != null) restore(state);
      if (session != null) {
        session!.status = 'paused';
        recovery = true;
        _segment = session!.points.isEmpty
            ? 1
            : session!.points.last.segment + 1;
        demo = session!.demo;
      }
      ready = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _heartbeat());
      _startDeviceStatus();
    } catch (e) {
      error = 'Не удалось загрузить данные: $e';
    }
    if (!_disposed) notifyListeners();
  }

  void restore(Map<String, dynamic> s) {
    favorites = Set<String>.from(s['favorites'] ?? []);
    saved = Set<String>.from(s['saved'] ?? []);
    checklist = Set<int>.from(s['checklist'] ?? []);
    routes.addAll(
      (s['routes'] as List? ?? [])
          .map((r) => HikingRoute.fromJson(Map<String, dynamic>.from(r)))
          .where((r) => !routes.any((a) => a.id == r.id)),
    );
    routeId = s['routeId'] ?? 'demo-kok';
    contact = s['contact'] ?? '';
    demo = s['demo'] ?? true;
    turnAt = DateTime.tryParse(s['turnAt'] ?? '');
    returnAt = DateTime.tryParse(s['returnAt'] ?? '');
    nextCheckInAt = DateTime.tryParse(s['nextCheckInAt'] ?? '');
    signalsEnabled = s['signalsEnabled'] != false;
    voiceEnabled = s['voiceEnabled'] == true;
    if (s['weather'] != null) {
      try {
        weather = WeatherSnapshot.fromJson(
          Map<String, dynamic>.from(s['weather']),
        );
      } catch (_) {}
    }
    deviationThreshold = (s['threshold'] as num?)?.toDouble() ?? 70;
    safety = SafetyEngine(threshold: deviationThreshold);
    session = s['session'] == null
        ? null
        : HikeSession.fromJson(Map<String, dynamic>.from(s['session']));
    history = (s['history'] as List? ?? [])
        .map((j) => HikeSession.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    if (s['realPosition'] != null) {
      realPosition = TrackPoint.fromJson(
        Map<String, dynamic>.from(s['realPosition']),
      );
    }
  }

  Map<String, dynamic> snapshot() => {
    'favorites': favorites.toList(),
    'saved': saved.toList(),
    'checklist': checklist.toList(),
    'routes': routes
        .where((r) => r.id != 'demo-kok')
        .map((r) => r.toJson())
        .toList(),
    'routeId': routeId,
    'contact': contact,
    'demo': demo,
    'turnAt': turnAt?.toIso8601String(),
    'returnAt': returnAt?.toIso8601String(),
    'nextCheckInAt': nextCheckInAt?.toIso8601String(),
    'signalsEnabled': signalsEnabled,
    'voiceEnabled': voiceEnabled,
    'weather': weather?.toJson(),
    'session': session?.toJson(),
    'history': history.map((s) => s.toJson()).toList(),
    'threshold': deviationThreshold,
    'realPosition': realPosition?.toJson(),
  };
  Future<void> persist() {
    final copy = jsonDecode(jsonEncode(snapshot())) as Map<String, dynamic>;
    _pending = _pending.then((_) async {
      try {
        await store.write('user', copy);
        storageError = null;
      } catch (e) {
        storageError = 'Данные не сохранены: $e';
      }
      if (!_disposed) notifyListeners();
    });
    return _pending;
  }

  void changed() {
    notifyListeners();
    unawaited(persist());
  }

  void favorite(String id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    changed();
  }

  void saveRoute(String id) {
    saved.add(id);
    changed();
  }

  void selectPlace(String id) {
    selectedPlace = id;
    notifyListeners();
  }

  void selectRoute(String id) {
    if (session != null) return;
    routeId = id;
    changed();
  }

  void setDemo(bool value) {
    if (session != null) return;
    demo = value;
    demoPosition = null;
    alerts.clear();
    changed();
  }

  void setThreshold(double value) {
    deviationThreshold = value;
    safety = SafetyEngine(threshold: value);
    changed();
  }

  void toggleCheck(int i, bool value) {
    value ? checklist.add(i) : checklist.remove(i);
    changed();
  }

  Future<void> updateWeather() async {
    if (weatherLoading) return;
    weatherLoading = true;
    weatherError = null;
    notifyListeners();
    try {
      weather = await fetchRouteWeather(route);
      changed();
    } catch (_) {
      weatherError =
          'Не удалось обновить прогноз. Сохранённый прогноз мог устареть.';
      notifyListeners();
    } finally {
      weatherLoading = false;
      notifyListeners();
    }
  }

  void checkIn() {
    nextCheckInAt = DateTime.now().add(const Duration(minutes: 15));
    alerts.removeWhere(
      (alert) => alert.startsWith('Время возвращения прошло.'),
    );
    changed();
  }

  void setSignals({bool? vibration, bool? voice}) {
    if (vibration != null) signalsEnabled = vibration;
    if (voice != null) voiceEnabled = voice;
    changed();
  }

  Future<void> signal(String message) async {
    if (signalsEnabled) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
    if (voiceEnabled) {
      try {
        await _tts.setLanguage('ru-RU');
        await _tts.setSpeechRate(.46);
        await _tts.speak(message);
      } catch (_) {}
    }
  }

  Future<void> importRoute(Map<String, dynamic> json) async {
    if (session != null) {
      throw StateError('Завершите текущий поход перед импортом');
    }
    final r = HikingRoute.fromGeoJson(json);
    routes.add(r);
    routeId = r.id;
    saved.add(r.id);
    changed();
  }

  Future<void> locate() async {
    try {
      realPosition = await GpsSource.current();
      gpsStatus = 'GPS получен';
      changed();
    } catch (e) {
      gpsStatus = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> start() async {
    if (session != null) return;
    if (!demo && route.demo) {
      throw StateError(
        'Демонстрационный трек доступен только в ДЕМО. Импортируйте свой GeoJSON для записи реального похода.',
      );
    }
    if (!demo) await GpsSource.ensurePermission();
    session = HikeSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      routeId: routeId,
      demo: demo,
      started: DateTime.now(),
    );
    alerts.clear();
    _segment = 0;
    nextCheckInAt = null;
    _lastReturnAlertAt = null;
    demoPosition = null;
    safety = SafetyEngine(threshold: deviationThreshold);
    _listen();
    changed();
  }

  void _listen() {
    _lastTick = DateTime.now();
    final LocationSource source;
    if (demo) {
      demoSource = DemoSource(route);
      source = demoSource!;
    } else {
      source = GpsSource();
    }
    _gps = source.positions().listen(
      acceptPoint,
      onError: (Object e) {
        gpsStatus = 'Ошибка GPS: $e';
        notifyListeners();
      },
    );
  }

  void acceptPoint(TrackPoint p) {
    if (!active || p.demo != session!.demo) return;
    final now = DateTime.now();
    if (!p.lat.isFinite ||
        !p.lon.isFinite ||
        p.lat.abs() > 90 ||
        p.lon.abs() > 180 ||
        p.accuracy < 0 ||
        p.accuracy > 50 ||
        now.difference(p.time) > const Duration(seconds: 30) ||
        p.time.isAfter(now.add(const Duration(seconds: 5)))) {
      gpsStatus = 'GPS неточный или устарел; точка не записана';
      notifyListeners();
      return;
    }
    final last = session!.points.lastOrNull;
    if (last != null) {
      final seconds = p.time.difference(last.time).inMilliseconds / 1000;
      if (seconds <= 0) return;
      if (seconds > 30) _segment++;
      if (!p.demo &&
          last.segment == _segment &&
          distanceMeters(last.lat, last.lon, p.lat, p.lon) >
              seconds * 12 + last.accuracy + p.accuracy) {
        gpsStatus = 'GPS-скачок отфильтрован';
        notifyListeners();
        return;
      }
    }
    final point = TrackPoint(
      p.lat,
      p.lon,
      p.time,
      accuracy: p.accuracy,
      demo: p.demo,
      segment: _segment,
    );
    session!.points.add(point);
    if (p.demo) {
      demoPosition = point;
    } else {
      realPosition = point;
    }
    gpsStatus = p.demo
        ? 'ДЕМО — координаты смоделированы'
        : 'GPS • ±${point.accuracy.round()} м';
    if (safety.update(point, route.points, now)) {
      alerts.insert(
        0,
        'Возможно, вы отклонились от выбранного маршрута. Проверьте положение на карте.',
      );
      unawaited(
        signal('Вы отклонились от маршрута. Проверьте своё положение.'),
      );
    }
    changed();
  }

  Future<void> pause() async {
    await _gps?.cancel();
    _gps = null;
    session?.status = 'paused';
    _segment++;
    _lastTick = null;
    changed();
  }

  Future<void> resume() async {
    if (session == null || active) return;
    if (!demo) await GpsSource.ensurePermission();
    session!.status = 'active';
    recovery = false;
    _listen();
    changed();
  }

  Future<void> finish() async {
    await _gps?.cancel();
    _gps = null;
    if (session != null) {
      session!.status = 'finished';
      history.insert(0, session!);
    }
    session = null;
    nextCheckInAt = null;
    _lastReturnAlertAt = null;
    recovery = false;
    demoPosition = null;
    alerts.clear();
    changed();
  }

  Future<void> background() async {
    if (active) {
      await pause();
      gpsStatus =
          'Запись приостановлена: приложение свернуто. Нажмите «Продолжить» после возвращения.';
      notifyListeners();
    }
  }

  void _heartbeat() {
    final now = DateTime.now();
    if (active) {
      if (_lastTick != null) {
        _elapsedRemainderMs += now
            .difference(_lastTick!)
            .inMilliseconds
            .clamp(0, 5000);
        session!.elapsedSeconds += _elapsedRemainderMs ~/ 1000;
        _elapsedRemainderMs %= 1000;
      }
      _lastTick = now;
      if (turnAt != null &&
          !now.isBefore(turnAt!) &&
          !alerts.contains('Наступило заданное время разворота.')) {
        alerts.insert(0, 'Наступило заданное время разворота.');
        unawaited(signal('Наступило время разворота.'));
      }
      if (returnOverdue &&
          (_lastReturnAlertAt == null ||
              now.difference(_lastReturnAlertAt!) >=
                  const Duration(minutes: 15))) {
        _lastReturnAlertAt = now;
        alerts.insert(
          0,
          'Время возвращения прошло. Подтвердите, что вы в безопасности, и сообщите близкому.',
        );
        unawaited(
          signal(
            'Время возвращения прошло. Подтвердите, что вы в безопасности.',
          ),
        );
      }
      if (battery != null &&
          battery! <= 20 &&
          !alerts.contains('Низкий заряд телефона: 20% или меньше.')) {
        alerts.insert(0, 'Низкий заряд телефона: 20% или меньше.');
        unawaited(signal('Низкий заряд телефона.'));
      }
      if (++_tick % 5 == 0) unawaited(persist());
      if (_tick % 60 == 0) unawaited(refreshBattery());
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _startDeviceStatus() async {
    try {
      final status = await Connectivity().checkConnectivity();
      _connection(status);
      _network = Connectivity().onConnectivityChanged.listen(_connection);
    } catch (_) {
      connection = 'Статус сети недоступен';
    }
    if (!kIsWeb) {
      try {
        battery = await Battery().batteryLevel;
      } catch (_) {}
    }
    if (!_disposed) notifyListeners();
  }

  void _connection(List<ConnectivityResult> c) {
    connection = c.contains(ConnectivityResult.none)
        ? 'Нет подключения к сети'
        : 'Сеть подключена • интернет не проверен';
    if (!_disposed) notifyListeners();
  }

  Future<void> refreshBattery() async {
    if (!kIsWeb) {
      try {
        battery = await Battery().batteryLevel;
        notifyListeners();
      } catch (_) {}
    }
  }

  bool get stale =>
      position == null ||
      DateTime.now().difference(position!.time) > const Duration(seconds: 30);
  Future<void> clearData() async {
    await _gps?.cancel();
    _gps = null;
    session = null;
    history.clear();
    favorites.clear();
    saved.clear();
    checklist.clear();
    contact = '';
    realPosition = null;
    demoPosition = null;
    routes.removeWhere((r) => r.id != 'demo-kok');
    routeId = 'demo-kok';
    turnAt = null;
    returnAt = null;
    nextCheckInAt = null;
    weather = null;
    signalsEnabled = true;
    voiceEnabled = false;
    alerts.clear();
    demo = true;
    await _pending;
    await store.clear();
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _gps?.cancel();
    _network?.cancel();
    super.dispose();
  }
}
