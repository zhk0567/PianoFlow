import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/guide_retrigger_gate.dart';

void main() {
  test('guide echo without gap does not auto-hit', () {
    final g = GuideRetriggerGate();
    g.arm([60]);
    // Echo still in suppress window — absence from heard must not open the gate.
    expect(
      g.acceptHits(
        heard: const {},
        waitingFor: {60},
        stillSuppressed: {60},
      ),
      isEmpty,
    );
    expect(g.blocks(60), isTrue);
    expect(g.gapSeen, isEmpty);

    // Suppress ended but mic still hears guide ring — still blocked.
    expect(
      g.acceptHits(
        heard: {60},
        waitingFor: {60},
        stillSuppressed: const {},
      ),
      isEmpty,
    );
    expect(g.blocks(60), isTrue);
  });

  test('single quiet frame after suppress is not enough gap', () {
    final g = GuideRetriggerGate();
    g.arm([60]);
    // One empty frame (estimator flicker) must not open the gate.
    expect(
      g.acceptHits(
        heard: const {},
        waitingFor: {60},
        stillSuppressed: const {},
      ),
      isEmpty,
    );
    expect(g.blocks(60), isTrue);
    expect(g.gapSeen, isEmpty);

    // Residual echo next frame — still blocked, streak resets.
    expect(
      g.acceptHits(
        heard: {60},
        waitingFor: {60},
      ),
      isEmpty,
    );
    expect(g.blocks(60), isTrue);
  });

  test('quiet streak then re-strike accepts hit', () {
    final g = GuideRetriggerGate();
    g.arm([60, 64]);

    // Need defaultQuietFramesNeeded empty frames.
    for (var i = 0; i < GuideRetriggerGate.defaultQuietFramesNeeded; i++) {
      expect(
        g.acceptHits(
          heard: const {},
          waitingFor: {60, 64},
          stillSuppressed: const {},
        ),
        isEmpty,
      );
    }
    expect(g.blocks(60), isFalse);
    expect(g.gapSeen, {60, 64});

    // User plays both.
    expect(
      g.acceptHits(
        heard: {60, 64},
        waitingFor: {60, 64},
      ),
      {60, 64},
    );
    expect(g.awaitingGap, isEmpty);
  });

  test('hearing mid-streak resets quiet counter', () {
    final g = GuideRetriggerGate(quietFramesNeeded: 3);
    g.arm([60]);
    g.acceptHits(heard: const {}, waitingFor: {60});
    g.acceptHits(heard: const {}, waitingFor: {60});
    expect(g.gapSeen, isEmpty);
    // Bleed returns — streak must restart.
    g.acceptHits(heard: {60}, waitingFor: {60});
    g.acceptHits(heard: const {}, waitingFor: {60});
    g.acceptHits(heard: const {}, waitingFor: {60});
    expect(g.gapSeen, isEmpty);
    g.acceptHits(heard: const {}, waitingFor: {60});
    expect(g.gapSeen, {60});
  });

  test('notes without guide arm hit immediately', () {
    final g = GuideRetriggerGate();
    expect(
      g.acceptHits(heard: {72}, waitingFor: {72}),
      {72},
    );
  });

  test('suppress frame resets streak even if heard empty', () {
    final g = GuideRetriggerGate(quietFramesNeeded: 2);
    g.arm([60]);
    g.acceptHits(heard: const {}, waitingFor: {60});
    // Back in suppress — must not keep the streak.
    g.acceptHits(
      heard: const {},
      waitingFor: {60},
      stillSuppressed: {60},
    );
    g.acceptHits(heard: const {}, waitingFor: {60});
    expect(g.gapSeen, isEmpty);
    g.acceptHits(heard: const {}, waitingFor: {60});
    expect(g.gapSeen, {60});
  });
}
