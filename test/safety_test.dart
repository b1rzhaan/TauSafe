import 'package:flutter_test/flutter_test.dart';
import 'package:tausafe/core/models.dart';
import 'package:tausafe/core/safety.dart';
import 'package:tausafe/core/storage.dart';

void main() {
  final time = DateTime.utc(2026, 9, 26, 10);
  final line = [
    [77.0, 43.0],
    [77.02, 43.0],
  ];
  TrackPoint p(
    double lat,
    int seconds, {
    double accuracy = 8,
    bool demo = false,
  }) => TrackPoint(
    lat,
    77.01,
    time.add(Duration(seconds: seconds)),
    accuracy: accuracy,
    demo: demo,
  );
  test('distance to interior of segment and degenerate endpoint', () {
    expect(
      distanceToSegment(p(43.001, 0), line[0], line[1]),
      closeTo(111.195, .5),
    );
    expect(distanceToSegment(TrackPoint(43, 77, time), line[0], line[0]), 0);
    expect(
      distanceToSegment(TrackPoint(43, 77.03, time), line[0], line[1]),
      closeTo(813, 5),
    );
  });
  test('accuracy suppresses uncertain deviation', () {
    final e = SafetyEngine();
    for (int i = 0; i < 5; i++) {
      expect(
        e.update(
          p(43.0008, i, accuracy: 45),
          line,
          time.add(Duration(seconds: i)),
        ),
        false,
      );
    }
  });
  test('three consecutive fixes, hysteresis and cooldown', () {
    final e = SafetyEngine();
    for (int i = 0; i < 2; i++) {
      expect(
        e.update(p(43.002, i), line, time.add(Duration(seconds: i))),
        false,
      );
    }
    expect(
      e.update(p(43.002, 2), line, time.add(const Duration(seconds: 2))),
      true,
    );
    expect(
      e.update(p(43.002, 3), line, time.add(const Duration(seconds: 3))),
      false,
    );
    expect(
      e.update(p(43, 4), line, time.add(const Duration(seconds: 4))),
      false,
    );
    for (int i = 5; i < 9; i++) {
      expect(
        e.update(p(43.002, i), line, time.add(Duration(seconds: i))),
        false,
      );
    }
    for (int i = 130; i < 132; i++) {
      expect(
        e.update(p(43.002, i), line, time.add(Duration(seconds: i))),
        false,
      );
    }
    expect(
      e.update(p(43.002, 132), line, time.add(const Duration(seconds: 132))),
      true,
    );
  });
  test('stale, inaccurate and duplicate fixes cannot count', () {
    final e = SafetyEngine();
    expect(
      e.update(p(43.002, 0), line, time.add(const Duration(minutes: 2))),
      false,
    );
    for (int i = 0; i < 6; i++) {
      expect(
        e.update(
          p(43.002, 5, accuracy: 90),
          line,
          time.add(const Duration(seconds: 5)),
        ),
        false,
      );
    }
    expect(
      e.update(p(43.002, 10), line, time.add(const Duration(seconds: 10))),
      false,
    );
    expect(
      e.update(p(43.002, 10), line, time.add(const Duration(seconds: 10))),
      false,
    );
  });
  test('SOS never substitutes demo location into real message', () {
    final m = sosMessage(
      route: 'A',
      point: p(43, 0, demo: true),
      now: time,
      demo: false,
    );
    expect(m, contains('не определены'));
    expect(m, isNot(contains('43.000000')));
  });
  test('SOS labels old fix and missing fix', () {
    expect(
      sosMessage(
        route: 'A',
        point: p(43, 0),
        now: time.add(const Duration(minutes: 3)),
      ),
      contains('УСТАРЕЛИ'),
    );
    expect(
      sosMessage(route: 'A', point: null, now: time),
      contains('Координаты: не определены'),
    );
  });
  test('session survives storage with track provenance and segments', () async {
    final store = MemoryStore();
    await store.open();
    final hike = HikeSession(
      id: '1',
      routeId: 'a',
      demo: true,
      started: time,
      elapsedSeconds: 14,
      points: [
        TrackPoint(43, 77, time, demo: true),
        TrackPoint(
          43.001,
          77,
          time.add(const Duration(seconds: 2)),
          demo: true,
          segment: 1,
        ),
      ],
    );
    await store.write('hike', hike.toJson());
    final restored = HikeSession.fromJson((await store.read('hike'))!);
    expect(restored.points.last.segment, 1);
    expect(restored.points.last.demo, true);
    expect(restored.elapsedSeconds, 14);
    expect(restored.distance, 0);
  });
  test('route roundtrip and import validation', () async {
    final store = MemoryStore();
    final route = HikingRoute.fromGeoJson({
      'type': 'LineString',
      'coordinates': line,
    });
    await store.write('route', route.toJson());
    final read = HikingRoute.fromJson((await store.read('route'))!);
    expect(read.points, line);
    expect(read.demo, false);
    expect(read.distance, greaterThan(1600));
    expect(
      () => HikingRoute.fromGeoJson({
        'type': 'LineString',
        'coordinates': [
          [999, 43],
          [77, 43],
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => HikingRoute.fromGeoJson({
        'type': 'Point',
        'coordinates': [77, 43],
      }),
      throwsFormatException,
    );
  });
}
