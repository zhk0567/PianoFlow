import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/basic_pitch.dart';

void main() {
  List<double> emptyScores() => List<double>.filled(88, 0.0);

  void setMidi(List<double> scores, int midi, double s) {
    scores[midi - 21] = s;
  }

  test('partial ghost drops octave and 3rd harmonic', () {
    final scores = emptyScores();
    setMidi(scores, 60, 0.55); // C4
    setMidi(scores, 64, 0.60); // E4
    setMidi(scores, 76, 0.48); // E5 ghost
    setMidi(scores, 79, 0.45); // G5 ghost

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, containsAll([60, 64]));
    expect(selected.contains(76), isFalse);
    expect(selected.contains(79), isFalse);
  });

  test('bass H2-only peak folds to C#2 fundamental', () {
    // Mic often reports C#3 (49) while C#2 (37) fund is weak — Moonlight LH.
    final scores = emptyScores();
    setMidi(scores, 37, 0.24); // C#2 weak fund
    setMidi(scores, 49, 0.58); // C#3 strong H2

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, contains(37));
    expect(selected.contains(49), isFalse);
  });

  test('true C#2+C#3 octave keeps both when both strong', () {
    final scores = emptyScores();
    setMidi(scores, 37, 0.50);
    setMidi(scores, 49, 0.55);

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, containsAll([37, 49]));
  });

  test('true mid C3 alone is not folded to C2 without fund energy', () {
    final scores = emptyScores();
    setMidi(scores, 48, 0.60); // C3
    // C2 near silence
    setMidi(scores, 36, 0.05);

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, contains(48));
    expect(selected.contains(36), isFalse);
  });

  test('weak bass fund enters via lowered bass floor', () {
    final scores = emptyScores();
    setMidi(scores, 36, 0.28); // C2 below normal relative floor of peak
    setMidi(scores, 60, 0.62); // C4 peak

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, contains(36));
    expect(selected, contains(60));
  });

  test('neighbor bleed drops weak ±1 of stronger peak', () {
    final scores = emptyScores();
    setMidi(scores, 60, 0.62); // C4
    setMidi(scores, 61, 0.48); // C#4 smear (< 0.88 * 0.62)

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, contains(60));
    expect(selected.contains(61), isFalse);
  });

  test('true minor second keeps both when scores are close', () {
    final scores = emptyScores();
    setMidi(scores, 60, 0.58);
    setMidi(scores, 61, 0.55); // ≥ 0.88 * 0.58

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, containsAll([60, 61]));
  });

  test('strong treble drops weaker subharmonic octave ghosts', () {
    // Played D5+A5; BP often also lights weak A4/A3 under A5.
    final scores = emptyScores();
    setMidi(scores, 81, 0.72); // A5 strongest
    setMidi(scores, 74, 0.58); // D5 real fifth
    setMidi(scores, 69, 0.50); // A4 ghost (octave below A5)
    setMidi(scores, 57, 0.48); // A3 ghost (2 octaves)

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, containsAll([74, 81]));
    expect(selected.contains(69), isFalse);
    expect(selected.contains(57), isFalse);
  });

  test('true mid octave dyad keeps both when lower is nearly as strong', () {
    final scores = emptyScores();
    setMidi(scores, 60, 0.55); // C4
    setMidi(scores, 72, 0.58); // C5

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected, containsAll([60, 72]));
  });

  test('sub-C2 ambient rumble does not lock on lowered bass floor', () {
    // Idle-room BP often lights a weak G#1 (32) under the old bass discount.
    final scores = emptyScores();
    setMidi(scores, 32, 0.28); // G#1 — above old bassFloor, below normal floor
    setMidi(scores, 60, 0.20); // weak mid clutter

    final selected = BasicPitchEstimator.selectNotes(scores);
    expect(selected.contains(32), isFalse);
  });
}
