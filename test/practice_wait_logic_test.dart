import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_constants.dart';
import 'package:piano_flow/features/practice/practice_wait_logic.dart';
import 'package:piano_flow/shared/models/song.dart';

ScoreNote _n(int midi, double start, {double dur = 1, Hand hand = Hand.right}) {
  return ScoreNote(midi: midi, start: start, duration: dur, hand: hand);
}

void main() {
  final notes = [
    _n(60, 0.0),
    _n(62, 1.0),
    _n(64, 3.0), // 2-beat gap after 62
    _n(67, 3.0, hand: Hand.left), // chord with 64
  ];

  test('far before onset: no wait (waterfall free-advances)', () {
    expect(
      PracticeWaitLogic.expectedAt(notes: notes, pos: -0.5),
      isEmpty,
    );
    expect(
      PracticeWaitLogic.expectedAt(notes: notes, pos: 0.0 - 0.6),
      isEmpty,
    );
  });

  test('early-hit window exposes upcoming chord', () {
    final early = PracticeConstants.waitEarlyHitBeats;
    final at = PracticeWaitLogic.expectedAt(notes: notes, pos: 1.0 - early);
    expect(at, {62});
    final mid = PracticeWaitLogic.expectedAt(
      notes: notes,
      pos: 1.0 - early / 2,
    );
    expect(mid, {62});
  });

  test('at onset freezes and expects chord cluster', () {
    expect(PracticeWaitLogic.expectedAt(notes: notes, pos: 3.0), {64, 67});
    expect(
      PracticeWaitLogic.shouldFreezeAt(pos: 3.0, chordStart: 3.0),
      isTrue,
    );
    expect(
      PracticeWaitLogic.shouldFreezeAt(pos: 2.7, chordStart: 3.0),
      isFalse,
    );
  });

  test('nudgePastChord does not teleport across gaps', () {
    final nudged = PracticeWaitLogic.nudgePastChord(notes: notes, pos: 1.0);
    expect(nudged, closeTo(1.0 + PracticeConstants.waitAdvanceEpsilonBeats, 1e-9));
    // Must stay well before the note at 3.0 so gap travel remains.
    expect(nudged, lessThan(2.0));
  });

  test('early hit nudge still lands just past target onset', () {
    final pos = 1.0 - 0.2;
    final nudged = PracticeWaitLogic.nudgePastChord(notes: notes, pos: pos);
    expect(nudged, closeTo(1.0 + PracticeConstants.waitAdvanceEpsilonBeats, 1e-9));
  });
}
