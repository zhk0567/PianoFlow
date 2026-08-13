import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_hit_latency.dart';

void main() {
  setUp(PracticeHitLatency.reset);

  test('record keeps rolling window and average', () {
    expect(PracticeHitLatency.averageMs, isNull);
    PracticeHitLatency.record(100);
    PracticeHitLatency.record(200);
    expect(PracticeHitLatency.samplesMs, [100, 200]);
    expect(PracticeHitLatency.averageMs, closeTo(150, 0.01));
  });

  test('negative elapsed clamps to 0', () {
    expect(PracticeHitLatency.record(-5), 0);
  });
}
