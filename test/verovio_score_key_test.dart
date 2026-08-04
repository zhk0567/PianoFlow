import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/practice/staff/score_to_musicxml.dart';
import 'package:piano_flow/features/practice/verovio_runtime.dart';
import 'package:piano_flow/shared/models/song.dart';

void main() {
  test('scoreKey and musicXmlCacheKey encode id + hand', () {
    const score = SongScore(
      id: 'demo',
      title: 'Demo',
      bpm: 100,
      notes: [],
    );
    expect(VerovioRuntime.scoreKey(score, Hand.both), 'demo|both');
    expect(VerovioRuntime.scoreKey(score, Hand.left), 'demo|left');
    expect(VerovioRuntime.musicXmlCacheKey('demo', Hand.right), 'demo|right');
  });

  test('practice MusicXML is always SongScore-derived (all hands)', () {
    final score = SongScore(
      id: 'demo',
      title: 'Demo',
      bpm: 120,
      notes: [
        ScoreNote(midi: 60, start: 0, duration: 1, hand: Hand.right),
        ScoreNote(midi: 48, start: 0, duration: 1, hand: Hand.left),
      ],
    );
    for (final hand in Hand.values) {
      final xml = songScoreToMusicXml(score, hand: hand);
      expect(xml.contains('<pitch>'), isTrue, reason: hand.name);
      expect(xml.contains('per-minute>120'), isTrue);
    }
    final rightOnly = songScoreToMusicXml(score, hand: Hand.right);
    final leftOnly = songScoreToMusicXml(score, hand: Hand.left);
    expect(rightOnly.contains('<octave>4</octave>'), isTrue);
    expect(leftOnly.contains('<octave>3</octave>'), isTrue);
    expect(rightOnly.contains('<octave>3</octave>'), isFalse);
  });

  test('newer load epoch supersedes older (switch race model)', () {
    // Mirrors VerovioRuntime._loadEpoch ownership: only the latest epoch commits.
    var epoch = 0;
    var committed = '';

    Future<void> load(String id) async {
      final owned = ++epoch;
      await Future<void>.delayed(Duration.zero);
      if (owned != epoch) return; // stale
      committed = id;
    }

    // Fire A then B quickly — B must win.
    final a = load('A');
    final b = load('B');
    return Future.wait([a, b]).then((_) {
      expect(committed, 'B');
      expect(epoch, 2);
    });
  });
}
