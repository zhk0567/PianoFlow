import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/staff/score_to_musicxml.dart';
import 'package:piano_flow/shared/models/song.dart';

void main() {
  test('songScoreToMusicXml emits partwise with time/key and notes', () {
    final score = SongScore(
      id: 't',
      title: 'Test',
      bpm: 100,
      timeNum: 4,
      timeDen: 4,
      keySignature: 1,
      notes: const [
        ScoreNote(midi: 60, start: 0, duration: 1, hand: Hand.right),
        ScoreNote(midi: 48, start: 0, duration: 1, hand: Hand.left),
      ],
    );
    final xml = songScoreToMusicXml(score);
    expect(xml, contains('score-partwise'));
    expect(xml, contains('<fifths>1</fifths>'));
    expect(xml, contains('<beats>4</beats>'));
    expect(xml, contains('<step>C</step>'));
    expect(xml, contains('<staff>1</staff>'));
    expect(xml, contains('<staff>2</staff>'));
  });

  test('right-hand filter omits bass pitches from MusicXML', () {
    final score = SongScore(
      id: 't',
      title: 'Test',
      bpm: 100,
      notes: const [
        ScoreNote(midi: 72, start: 0, duration: 1, hand: Hand.right), // C5
        ScoreNote(midi: 36, start: 0, duration: 1, hand: Hand.left), // C2
      ],
    );
    final xml = songScoreToMusicXml(score, hand: Hand.right);
    expect(xml, contains('<step>C</step>'));
    expect(xml, contains('<octave>5</octave>'));
    expect(xml, isNot(contains('<octave>2</octave>')));
  });

  test('left-hand filter omits treble pitches from MusicXML', () {
    final score = SongScore(
      id: 't',
      title: 'Test',
      bpm: 100,
      notes: const [
        ScoreNote(midi: 72, start: 0, duration: 1, hand: Hand.right),
        ScoreNote(midi: 36, start: 0, duration: 1, hand: Hand.left),
      ],
    );
    final xml = songScoreToMusicXml(score, hand: Hand.left);
    expect(xml, contains('<octave>2</octave>'));
    expect(xml, isNot(contains('<octave>5</octave>')));
  });
}
