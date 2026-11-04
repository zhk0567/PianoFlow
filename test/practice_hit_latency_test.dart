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

  test('p50 p95 and guide buckets', () {
    for (var i = 1; i <= 10; i++) {
      PracticeHitLatency.record(i * 10, guideOn: i.isEven);
    }
    expect(PracticeHitLatency.hits, 10);
    expect(PracticeHitLatency.hitsGuideOn, 5);
    expect(PracticeHitLatency.hitsGuideOff, 5);
    expect(PracticeHitLatency.p50Ms, isNotNull);
    expect(PracticeHitLatency.p95Ms, isNotNull);
    expect(PracticeHitLatency.p50Ms!, lessThanOrEqualTo(PracticeHitLatency.p95Ms!));
    expect(PracticeHitLatency.p50GuideOnMs, isNotNull);
    expect(PracticeHitLatency.p50GuideOffMs, isNotNull);
  });

  test('frame path counts guide frame hits', () {
    PracticeHitLatency.record(40, guideOn: true, path: 'frame');
    PracticeHitLatency.record(50, guideOn: true, path: 'noteOn');
    PracticeHitLatency.record(60, guideOn: false, path: 'frame');
    expect(PracticeHitLatency.frameHitsGuideOn, 1);
  });

  test('counters and snapshotLine', () {
    PracticeHitLatency.record(120, guideOn: false);
    PracticeHitLatency.noteMiss();
    PracticeHitLatency.noteLatchBlock();
    PracticeHitLatency.noteSoftMatch();
    PracticeHitLatency.noteLeak();
    expect(PracticeHitLatency.misses, 1);
    expect(PracticeHitLatency.latchBlocks, 1);
    expect(PracticeHitLatency.softMatches, 1);
    expect(PracticeHitLatency.leaks, 1);
    expect(PracticeHitLatency.missRate, closeTo(0.5, 0.01));
    final line = PracticeHitLatency.snapshotLine();
    expect(line, contains('hits=1'));
    expect(line, contains('miss=1'));
    expect(line, contains('p50='));
    final snap = PracticeHitLatency.snapshot();
    expect(snap['hits'], 1);
    expect(snap['p50Ms'], isNotNull);
  });
}
