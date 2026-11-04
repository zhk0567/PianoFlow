import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/practice_pitch_match.dart';

void main() {
  test('exact match preferred', () {
    expect(
      PracticePitchMatch.matchWaiting(
        heard: {60, 64},
        waitingFor: {60, 64},
      ),
      {60, 64},
    );
  });

  test('±1 maps onto waiting pitch when monophonic', () {
    expect(
      PracticePitchMatch.matchWaiting(
        heard: {61},
        waitingFor: {60},
      ),
      {60},
    );
    expect(
      PracticePitchMatch.matchNoteOn(midi: 59, waitingFor: {60}),
      60,
    );
  });

  test('±1 does NOT soft-match on chords (score-conditioned)', () {
    expect(
      PracticePitchMatch.softSemitoneAllowed({60, 64}),
      isFalse,
    );
    expect(
      PracticePitchMatch.matchWaiting(
        heard: {61},
        waitingFor: {60, 64},
      ),
      isEmpty,
    );
    expect(
      PracticePitchMatch.matchNoteOn(midi: 61, waitingFor: {60, 64}),
      isNull,
    );
  });

  test('exact still works on chords', () {
    expect(
      PracticePitchMatch.matchWaiting(
        heard: {60, 64},
        waitingFor: {60, 64},
      ),
      {60, 64},
    );
  });

  test('conditionHeard drops junk outside neighborhood', () {
    expect(
      PracticePitchMatch.conditionHeard(
        heard: {60, 72, 80},
        waitingFor: {60},
      ),
      {60, 72}, // octave kept; 80 dropped
    );
  });

  test('priorBins includes neighbors and octaves', () {
    final bins = PracticePitchMatch.priorBins({60});
    expect(bins.contains(60), isTrue);
    expect(bins.contains(59), isTrue);
    expect(bins.contains(61), isTrue);
    expect(bins.contains(48), isTrue);
    expect(bins.contains(72), isTrue);
  });

  test('±2 is not a match', () {
    expect(
      PracticePitchMatch.matchNoteOn(midi: 62, waitingFor: {60}),
      isNull,
    );
  });

  test('bass H2 maps onto waiting fundamental', () {
    expect(
      PracticePitchMatch.matchNoteOn(midi: 49, waitingFor: {37}),
      37,
    );
    expect(
      PracticePitchMatch.matchWaiting(
        heard: {49},
        waitingFor: {37},
      ),
      {37},
    );
  });

  test('mid-range H2 maps onto waiting fundamental', () {
    expect(
      PracticePitchMatch.matchNoteOn(midi: 72, waitingFor: {60}),
      60,
    );
    expect(
      PracticePitchMatch.matchNoteOn(midi: 60, waitingFor: {72}),
      72,
    );
  });

  test('bass H2 does not steal when octave chord still owes H2', () {
    expect(
      PracticePitchMatch.matchWaiting(
        heard: {49},
        waitingFor: {37, 49},
      ),
      {49},
    );
  });

  test('isHeardNear includes octave relatives', () {
    expect(PracticePitchMatch.isHeardNear(37, {49}), isTrue);
    expect(PracticePitchMatch.isHeardNear(60, {72}), isTrue);
    expect(PracticePitchMatch.isHeardNear(37, {50}), isFalse);
  });

  test('chord wrong ±1 is not forgivable miss', () {
    expect(
      PracticePitchMatch.isForgivableWrongPitch(
        heard: 61,
        waitingFor: {60, 64},
      ),
      isFalse,
    );
    expect(
      PracticePitchMatch.isForgivableWrongPitch(
        heard: 61,
        waitingFor: {60},
      ),
      isTrue,
    );
  });
}
