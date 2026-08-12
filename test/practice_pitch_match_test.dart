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

  test('±1 maps onto waiting pitch', () {
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

  test('one heard MIDI consumes at most one waiting pitch', () {
    expect(
      PracticePitchMatch.matchWaiting(
        heard: {61},
        waitingFor: {60, 62},
      ),
      {60}, // tie → lower
    );
  });

  test('±2 is not a match', () {
    expect(
      PracticePitchMatch.matchNoteOn(midi: 62, waitingFor: {60}),
      isNull,
    );
  });
}
