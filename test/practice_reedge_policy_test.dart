import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_guide_hit_policy.dart';

void main() {
  test('reedge targets are tones already emitted before cue', () {
    final emitted = {60, 64};
    final already = PracticeGuideHitPolicy.midisToReedgeAfterSuppress(
      cued: {60, 67},
      isEmitted: emitted.contains,
    );
    expect(already, {60});
  });
}
