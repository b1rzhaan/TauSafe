import 'package:flutter_test/flutter_test.dart';
import 'package:tausafe/core/app_state.dart';
import 'package:tausafe/core/models.dart';
import 'package:tausafe/core/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('restart recovers unfinished session paused with same points', () async {
    final store = MemoryStore();
    final first = AppState(store);
    await first.initialize();
    first.session = HikeSession(
      id: 'test',
      routeId: 'demo-kok',
      demo: true,
      started: DateTime.now(),
      elapsedSeconds: 55,
      points: [
        TrackPoint(43.15, 77.04, DateTime.now(), demo: true, segment: 3),
      ],
    );
    first.favorites.add('kok');
    first.saved.add('demo-kok');
    await first.persist();
    first.dispose();
    final second = AppState(store);
    await second.initialize();
    expect(second.recovery, true);
    expect(second.session!.status, 'paused');
    expect(second.session!.elapsedSeconds, 55);
    expect(second.session!.points.single.segment, 3);
    expect(second.favorites, contains('kok'));
    expect(second.demoPosition, isNull);
    second.dispose();
  });
  test('real session rejects simulated fixes and implausible jumps', () async {
    final state = AppState(MemoryStore());
    await state.initialize();
    state.demo = false;
    state.session = HikeSession(
      id: 'test',
      routeId: 'demo-kok',
      demo: false,
      started: DateTime.now(),
    );
    state.acceptPoint(TrackPoint(43, 77, DateTime.now(), demo: true));
    expect(state.session!.points, isEmpty);
    state.acceptPoint(
      TrackPoint(43, 77, DateTime.now().subtract(const Duration(seconds: 2))),
    );
    state.acceptPoint(TrackPoint(44, 78, DateTime.now()));
    expect(state.session!.points.length, 1);
    expect(state.gpsStatus, contains('отфильтрован'));
    await state.persist();
    state.dispose();
  });
  test('demo route cannot start as real GPS hike', () async {
    final state = AppState(MemoryStore());
    await state.initialize();
    state.setDemo(false);
    await expectLater(state.start(), throwsStateError);
    expect(state.session, isNull);
    await state.persist();
    state.dispose();
  });
  test(
    'leaving demo clears simulated position and preserves real fix',
    () async {
      final state = AppState(MemoryStore());
      await state.initialize();
      state.demoPosition = TrackPoint(43, 77, DateTime.now(), demo: true);
      state.realPosition = TrackPoint(43.1, 77.1, DateTime.now());
      state.setDemo(false);
      expect(state.demoPosition, isNull);
      expect(state.position!.demo, false);
      await state.persist();
      state.dispose();
    },
  );

  test(
    'overdue check-in is deferred for 15 minutes and survives restart',
    () async {
      final store = MemoryStore();
      final first = AppState(store);
      await first.initialize();
      first.session = HikeSession(
        id: 'late',
        routeId: 'demo-kok',
        demo: true,
        started: DateTime.now().subtract(const Duration(hours: 2)),
      );
      first.returnAt = DateTime.now().subtract(const Duration(minutes: 2));
      expect(first.returnOverdue, true);
      first.checkIn();
      expect(first.returnOverdue, false);
      await first.persist();
      first.dispose();

      final second = AppState(store);
      await second.initialize();
      expect(second.returnOverdue, false);
      expect(second.nextCheckInAt, isNotNull);
      second.dispose();
    },
  );
}
