import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final monitoringProvider = ChangeNotifierProvider(
  (ref) => Monitoring()..checkAi(),
);

class Observation {
  Observation({
    required this.title,
    required this.detail,
    required this.place,
    required this.lon,
    required this.lat,
    this.demo = true,
    this.ai = false,
  }) : time = DateTime.now();
  final String title, detail, place;
  final double lon, lat;
  final bool demo, ai;
  final DateTime time;
  bool read = false;
}

class Monitoring extends ChangeNotifier {
  String mode = 'patrol';
  bool visible = true, aiReady = false, analyzing = false, disposed = false;
  String aiStatus = 'Проверка подключения AI…';
  List<Map<String, dynamic>> fleet = [];
  final List<Observation> events = [];
  int scenario = 0;
  int get unread => events.where((e) => !e.read).length;
  Uri get endpoint {
    const configured = String.fromEnvironment('TAUSAFE_API_URL');
    if (configured.isNotEmpty) return Uri.parse(configured);
    return kIsWeb
        ? Uri.base.resolve('/api/')
        : Uri.parse('http://127.0.0.1:8765/api/');
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> checkAi() async {
    try {
      final r = await http
          .get(endpoint.resolve('health'))
          .timeout(const Duration(seconds: 3));
      final data = jsonDecode(r.body);
      aiReady = r.statusCode == 200 && data['aiConfigured'] == true;
      aiStatus = aiReady
          ? 'AI подключён · анализ по запросу'
          : 'AI не подключён · нужен ключ сервера';
    } catch (_) {
      aiReady = false;
      aiStatus = 'AI-сервер недоступен';
    }
    changed();
  }

  void receive(Map<String, dynamic> data) {
    // Only the local 3D demonstration emits these values, never real telemetry.
    if (data['demo'] != true) return;
    fleet = (data['drones'] as List).cast<Map<String, dynamic>>();
    changed();
  }

  void setMode(String value) {
    mode = value;
    changed();
  }

  void setVisible(bool value) {
    visible = value;
    changed();
  }

  void acknowledge(Observation event) {
    event.read = true;
    changed();
  }

  void simulate(String place, double lon, double lat) {
    final search = mode == 'search';
    final samples = [
      (
        'Изменение на склоне',
        'Демо: на условной паре кадров изменился участок осыпи. Требуется проверка оператором.',
      ),
      (
        'Снижение видимости',
        'Демо: часть ущелья закрыла облачность. Следующий кадр нужен для сравнения.',
      ),
      (
        'Объект рядом с тропой',
        'Демо: показана отметка объекта. По этому сигналу нельзя определить человека или его состояние.',
      ),
    ];
    final sample = search ? samples[2] : samples[scenario++ % samples.length];
    events.insert(
      0,
      Observation(
        title: sample.$1,
        detail: sample.$2,
        place: place,
        lon: lon,
        lat: lat,
      ),
    );
    if (events.length > 20) events.removeLast();
    changed();
  }

  Future<void> compareFrames({
    required String before,
    required String after,
    required String place,
    required double lon,
    required double lat,
  }) async {
    if (!aiReady || analyzing) return;
    analyzing = true;
    changed();
    try {
      final r = await http
          .post(
            endpoint.resolve('analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'before': before,
              'after': after,
              'place': place,
            }),
          )
          .timeout(const Duration(seconds: 65));
      if (r.statusCode != 200) {
        throw StateError(
          'AI не выполнил анализ (${r.statusCode}). Попробуйте позже.',
        );
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final changes = (data['changes'] as List).join('\n');
      events.insert(
        0,
        Observation(
          title: 'AI: сравнение кадров',
          detail:
              '${data['summary']}\n$changes\nВыводы требуют проверки человеком.',
          place: place,
          lon: lon,
          lat: lat,
          demo: false,
          ai: true,
        ),
      );
      if (events.length > 20) events.removeLast();
    } finally {
      analyzing = false;
      changed();
    }
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
