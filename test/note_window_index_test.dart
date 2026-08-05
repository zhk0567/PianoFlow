import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/note_window_index.dart';
import 'package:piano_flow/shared/models/song.dart';

ScoreNote _n(int midi, double start, {double dur = 1}) =>
    ScoreNote(midi: midi, start: start, duration: dur, hand: Hand.right);

void main() {
  final notes = [
    _n(60, 0),
    _n(62, 1),
    _n(64, 2),
    _n(65, 5),
    _n(67, 10),
    _n(69, 10.5),
  ];

  test('lowerBoundStart / upperBoundStart', () {
    expect(NoteWindowIndex.lowerBoundStart(notes, 2), 2);
    expect(NoteWindowIndex.upperBoundStart(notes, 2), 3);
    expect(NoteWindowIndex.lowerBoundStart(notes, 3), 3);
  });

  test('visibleAround returns only nearby onsets', () {
    final vis = NoteWindowIndex.visibleAround(
      notes: notes,
      pos: 10,
      lookBehind: 0.5,
      lookAhead: 1,
    );
    expect(vis.map((n) => n.midi), containsAll([67, 69]));
    expect(vis.any((n) => n.midi == 60), isFalse);
  });

  test('activeMidiAt finds sounding notes', () {
    expect(NoteWindowIndex.activeMidiAt(notes, 0.5), {60});
    expect(NoteWindowIndex.activeMidiAt(notes, 10.2), {67});
  });

  test('NoteOnsetCursor takeDue advances monotonically', () {
    final c = NoteOnsetCursor();
    expect(c.takeDue(notes, 0.5).map((n) => n.midi), [60]);
    expect(c.takeDue(notes, 2.5).map((n) => n.midi), [62, 64]);
    expect(c.takeDue(notes, 2.5).map((n) => n.midi), isEmpty);
    c.seekBefore(notes, 10);
    expect(c.takeDue(notes, 10.6).map((n) => n.midi), [67, 69]);
  });
}
