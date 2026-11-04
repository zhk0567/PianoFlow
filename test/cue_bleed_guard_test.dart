import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/cue_bleed_guard.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';

void main() {
  test('user onset is never bleed', () {
    final g = CueBleedGuard();
    g.arm({60});
    expect(
      g.isBleed(midi: 60, hasOnset: true, heardAll: {60}),
      isFalse,
    );
  });

  test('onset-less cue pitch during hard window is bleed', () {
    final g = CueBleedGuard();
    g.arm({60});
    expect(
      g.isBleed(midi: 60, hasOnset: false, heardAll: {60}),
      isTrue,
    );
    expect(
      g.isBleed(midi: 61, hasOnset: false, heardAll: {61}),
      isTrue,
    );
  });

  test('unrelated pitch is not bleed', () {
    final g = CueBleedGuard();
    g.arm({60});
    expect(
      g.isBleed(midi: 64, hasOnset: false, heardAll: {64}),
      isFalse,
    );
  });

  test('soft tail only when heard is cue neighborhood', () {
    final g = CueBleedGuard(softTail: const Duration(milliseconds: 200));
    final past = DateTime.now().subtract(
      PracticeConstants.echoSuppressGuide + const Duration(milliseconds: 80),
    );
    g.arm({60}, at: past);
    expect(
      g.isBleed(midi: 60, hasOnset: false, heardAll: {60}),
      isTrue,
    );
    // Extra non-cue pitch ⇒ user activity, not pure bleed.
    expect(
      g.isBleed(midi: 60, hasOnset: false, heardAll: {60, 67}),
      isFalse,
    );
  });

  test('reedge grace right after hard suppress is not bleed', () {
    final g = CueBleedGuard(softTail: const Duration(milliseconds: 200));
    final past = DateTime.now().subtract(
      PracticeConstants.echoSuppressGuide + const Duration(milliseconds: 20),
    );
    g.arm({60}, at: past);
    expect(
      g.isBleed(midi: 60, hasOnset: false, heardAll: {60}),
      isFalse,
    );
  });

  test('after soft tail ends, no longer bleed', () {
    final g = CueBleedGuard(softTail: const Duration(milliseconds: 50));
    final past = DateTime.now().subtract(
      PracticeConstants.echoSuppressGuide + const Duration(milliseconds: 200),
    );
    g.arm({60}, at: past);
    expect(
      g.isBleed(midi: 60, hasOnset: false, heardAll: {60}),
      isFalse,
    );
  });

  test('clear disarms', () {
    final g = CueBleedGuard();
    g.arm({60});
    g.clear();
    expect(
      g.isBleed(midi: 60, hasOnset: false, heardAll: {60}),
      isFalse,
    );
  });
}
