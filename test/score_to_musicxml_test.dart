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
}
