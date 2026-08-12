import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_guide_hit_policy.dart';

void main() {
  test('noteOn blocked while echo suppressed', () {
    expect(
      PracticeGuideHitPolicy.resolveNoteOnHit(
        midi: 60,
        waitingFor: {60},
        echoSuppressed: true,
      ),
      isNull,
    );
  });

  test('noteOn after suppress maps ±1 without needing quiet gap', () {
    expect(
      PracticeGuideHitPolicy.resolveNoteOnHit(
        midi: 61,
        waitingFor: {60},
        echoSuppressed: false,
      ),
      60,
    );
  });

  test('noteOn wrong pitch after suppress is not a hit', () {
    expect(
      PracticeGuideHitPolicy.resolveNoteOnHit(
        midi: 64,
        waitingFor: {60},
        echoSuppressed: false,
      ),
      isNull,
    );
  });

  test('reedge only already-emitted cued bins (±1)', () {
    final emitted = {60, 72};
    expect(
      PracticeGuideHitPolicy.midisToReedgeAfterSuppress(
        cued: {60, 64},
        isEmitted: emitted.contains,
      ),
      {60},
    );
    expect(
      PracticeGuideHitPolicy.midisToReedgeAfterSuppress(
        cued: {60},
        isEmitted: (m) => m == 61,
      ),
      {61},
    );
    expect(
      PracticeGuideHitPolicy.midisToReedgeAfterSuppress(
        cued: {60},
        isEmitted: (_) => false,
      ),
      isEmpty,
    );
  });
}
