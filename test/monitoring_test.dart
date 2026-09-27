import 'package:flutter_test/flutter_test.dart';
import 'package:tausafe/core/monitoring.dart';

void main() {
  test(
    'demo search generates a reviewable event, never real AI or a rescue dispatch',
    () {
      final m = Monitoring()..setMode('search');
      m.simulate('Medeu', 77.0586, 43.1575);
      expect(m.events.single.demo, isTrue);
      expect(m.events.single.ai, isFalse);
      expect(m.aiReady, isFalse);
      expect(m.unread, 1);
      m.acknowledge(m.events.single);
      expect(m.unread, 0);
      m.dispose();
    },
  );
  test('unconfigured analysis does not fabricate an AI finding', () async {
    final m = Monitoring();
    await m.compareFrames(
      before: '',
      after: '',
      place: 'Medeu',
      lon: 77,
      lat: 43,
    );
    expect(m.events, isEmpty);
    m.dispose();
  });
}
