import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_models.dart';
import 'package:piano_flow/features/practice/practice_wait_logic.dart';
import 'package:piano_flow/shared/models/song.dart';

ScoreNote _n(int midi, double start, {double dur = 1, Hand hand = Hand.right}) {
  return ScoreNote(midi: midi, start: start, duration: dur, hand: hand);
}

void main() {
  final score = SongScore(
    id: 'demo',
    title: 'Demo',
    bpm: 120,
    notes: [
      _n(60, 0.0),
      _n(62, 1.0),
      _n(64, 3.0),
      _n(67, 3.0, hand: Hand.left),
    ],
  );

  PracticeSnapshot snap({
    required double pos,
    required PracticeMode mode,
    bool playing = true,
    double speed = 1.0,
    Set<int>? waitingFor,
  }) {
    final settings = PracticeSettings(mode: mode, speed: speed);
    final expected = mode.isAutoPlay
        ? <int>{}
        : PracticeWaitLogic.expectedAt(notes: score.notes, pos: pos);
    return PracticeSnapshot(
      score: score,
      settings: settings,
      positionBeats: pos,
      isPlaying: playing,
      waitingFor: waitingFor ?? expected,
      activeMidi: expected,
    );
  }

  test('autoPlay staff rate follows BPM×speed while playing', () {
    final s = snap(pos: 0.5, mode: PracticeMode.autoPlay);
    expect(s.staffBeatsPerSec, closeTo(2.0, 1e-9)); // 120/60
    expect(s.copyWith(isPlaying: false).staffBeatsPerSec, 0);
  });

  test('wait free-advance (gap) drives staff rate', () {
    // Between 1.0 and 3.0-early: after note at 1, before early window of 3.
    final s = snap(pos: 1.5, mode: PracticeMode.wait);
    expect(s.waitingFor, isEmpty);
    expect(s.isWaitFrozenAtOnset, isFalse);
    expect(s.staffBeatsPerSec, closeTo(2.0, 1e-9));
  });

  test('wait early window still drives staff rate', () {
    final s = snap(pos: 2.7, mode: PracticeMode.wait);
    expect(s.waitingFor, isNotEmpty);
    expect(s.isWaitFrozenAtOnset, isFalse);
    expect(s.staffBeatsPerSec, closeTo(2.0, 1e-9));
  });

  test('wait frozen at onset stops staff free-run', () {
    final s = snap(pos: 3.0, mode: PracticeMode.wait);
    expect(s.waitingFor, {64, 67});
    expect(s.isWaitFrozenAtOnset, isTrue);
    expect(s.staffBeatsPerSec, 0);
  });

  test('nudge then gap: staff rate resumes after leaving onset', () {
    final nudged = PracticeWaitLogic.nudgePastChord(
      notes: score.notes,
      pos: 1.0,
    );
    final s = snap(pos: nudged, mode: PracticeMode.wait);
    expect(s.isWaitFrozenAtOnset, isFalse);
    expect(s.staffBeatsPerSec, greaterThan(0));
  });
}
