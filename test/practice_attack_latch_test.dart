import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_attack_latch.dart';

void main() {
  test('same lock cannot re-hit after consume until quiet release', () {
    final latch = PracticeAttackLatch(
      releaseFrames: 2,
      postHitReleaseFrames: 2,
      onsetRefractoryFrames: 0,
    );
    latch.markConsumed(60, heardMidi: 60);
    expect(latch.blocks(60), isTrue);
    expect(latch.blocks(61), isTrue); // ±1 bin
    expect(latch.blocks(64), isFalse); // other chord tone OK

    // Still ringing — stay blocked.
    latch.onHeard({60});
    expect(latch.blocks(60), isTrue);

    // One quiet frame is not enough (flicker).
    latch.onHeard({});
    expect(latch.blocks(60), isTrue);

    // Second quiet frame releases.
    latch.onHeard({});
    expect(latch.blocks(60), isFalse);
  });

  test('post-hit quiet needs more frames than bare releaseFrames', () {
    final latch = PracticeAttackLatch(
      releaseFrames: 2,
      postHitReleaseFrames: 4,
      onsetRefractoryFrames: 99,
    );
    latch.markConsumed(60);
    latch.onHeard({});
    latch.onHeard({});
    expect(latch.blocks(60), isTrue); // only 2 quiet — not enough post-hit
    latch.onHeard({});
    latch.onHeard({});
    expect(latch.blocks(60), isFalse);
  });

  test('neighbor noteOn after consume is blocked (double-edge same attack)', () {
    final latch = PracticeAttackLatch();
    latch.markConsumed(60, heardMidi: 60);
    // Estimator often emits 60 then 61 in the same press.
    expect(latch.blocks(61), isTrue);
  });

  test('bass H2 heard stays spent with fundamental', () {
    final latch = PracticeAttackLatch(
      releaseFrames: 2,
      postHitReleaseFrames: 2,
      onsetRefractoryFrames: 0,
    );
    latch.markConsumed(36, heardMidi: 48);
    expect(latch.blocks(36), isTrue);
    expect(latch.blocks(48), isTrue);
    latch.onHeard({48});
    expect(latch.blocks(36), isTrue);
    latch.onHeard({});
    latch.onHeard({});
    expect(latch.blocks(36), isFalse);
  });

  test('mid-range octave bin stays spent with fundamental', () {
    final latch = PracticeAttackLatch(
      releaseFrames: 2,
      postHitReleaseFrames: 2,
      onsetRefractoryFrames: 0,
    );
    latch.markConsumed(60, heardMidi: 72);
    expect(latch.blocks(60), isTrue);
    expect(latch.blocks(72), isTrue);
    latch.onHeard({72});
    expect(latch.blocks(60), isTrue);
  });

  test('major-seventh chord tone is not blocked by octave smear', () {
    final latch = PracticeAttackLatch();
    latch.markConsumed(71); // B4
    expect(latch.blocks(60), isFalse); // C4 is 11 semitones, not the B octave
    expect(latch.blocks(59), isTrue); // B3
    expect(latch.blocks(72), isTrue); // C5 neighbor of B4
    latch.markConsumed(64);
    latch.markConsumed(67);
    expect(latch.blocks(60), isFalse);
  });

  test('chord mates remain hittable after one tone consumed', () {
    final latch = PracticeAttackLatch();
    latch.markConsumed(60);
    expect(latch.blocks(64), isFalse);
    expect(latch.blocks(67), isFalse);
    latch.markConsumed(64);
    expect(latch.blocks(67), isFalse);
  });

  test('releaseOnOnset blocked during post-hit refractory', () {
    final latch = PracticeAttackLatch(
      releaseFrames: 2,
      postHitReleaseFrames: 5,
      onsetRefractoryFrames: 3,
    );
    latch.markConsumed(60);
    latch.onHeard({60});
    latch.releaseOnOnset({60});
    expect(latch.blocks(60), isTrue); // refractory 3→2

    latch.onHeard({60});
    latch.releaseOnOnset({60});
    expect(latch.blocks(60), isTrue); // refractory 2→1

    latch.onHeard({60}); // 1→0 cleared
    latch.releaseOnOnset({60});
    expect(latch.blocks(60), isFalse); // 连击 path
  });

  test('releaseOnOnset ignores pitches not heard', () {
    final latch = PracticeAttackLatch(onsetRefractoryFrames: 0);
    latch.markConsumed(60);
    latch.releaseOnOnset({64});
    expect(latch.blocks(60), isTrue);
  });

  test('carryover blocks linger until quiet — even with onset', () {
    final latch = PracticeAttackLatch(carryoverQuietFrames: 3);
    // After hitting B5, G5 is still in the BP window when next wait arms.
    latch.armCarryover({71, 79}); // B5 + lingering G5
    expect(latch.blocksCarryover(79), isTrue);
    expect(latch.blocksCarryover(79, hasOnset: true), isTrue);
    // Soft ±1 of linger also blocked (scale false-advance).
    expect(latch.blocksCarryover(80, hasOnset: true), isTrue);
    // Far new pitch OK.
    expect(latch.blocksCarryover(64, hasOnset: true), isFalse);

    // Still hearing — stay blocked.
    latch.onHeard({79});
    expect(latch.blocksCarryover(79, hasOnset: true), isTrue);

    // Quiet long enough → cleared.
    latch.onHeard({});
    latch.onHeard({});
    latch.onHeard({});
    expect(latch.carryover.contains(79), isFalse);
    expect(latch.blocksCarryover(79, hasOnset: true), isFalse);
  });

  test('armCarryover merges successive snapshots', () {
    final latch = PracticeAttackLatch(carryoverQuietFrames: 2);
    latch.armCarryover({60});
    latch.armCarryover({64});
    expect(latch.carryover, containsAll([60, 64]));
  });
}
