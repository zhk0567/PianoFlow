import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/shared/models/song.dart';

void main() {
  test('SongScore parses notes and duration', () {
    const raw = '''
    {
      "id": "demo",
      "title": "Demo",
      "bpm": 120,
      "notes": [
        {"midi": 60, "start": 0.0, "duration": 1.0, "hand": "right"},
        {"midi": 48, "start": 0.0, "duration": 2.0, "hand": "left"},
        {"midi": 62, "start": 1.0, "duration": 1.0, "hand": "right"}
      ]
    }
    ''';
    final score = SongScore.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(score.notes.length, 3);
    expect(score.durationBeats, 2.0);
    expect(score.notesForHand(Hand.right).length, 2);
    expect(score.notesForHand(Hand.left).length, 1);
  });

  test('SongSummary ignores premium and reads durationHint', () {
    final summary = SongSummary.fromJson({
      'id': 'a',
      'title': 'T',
      'artist': 'A',
      'genre': '古典',
      'difficulty': 1,
      'bpm': 100,
      'asset': 'assets/scores/a.json',
      'description': 'd',
      'durationHint': 42,
      'premium': true,
    });
    expect(summary.durationHint, 42);
    expect(summary.formatDuration(), '0:42');
  });

  test('SongSummary reads scoreKind formal vs simplified', () {
    final formal = SongSummary.fromJson({
      'id': 'a',
      'title': 'T',
      'artist': 'A',
      'genre': '古典',
      'difficulty': 1,
      'bpm': 100,
      'asset': 'assets/scores/a.json',
      'scoreKind': 'formal',
    });
    final simplified = SongSummary.fromJson({
      'id': 'b',
      'title': 'T',
      'artist': 'A',
      'genre': '古典',
      'difficulty': 1,
      'bpm': 100,
      'asset': 'assets/scores/b.json',
    });
    expect(formal.scoreKind, ScoreKind.formal);
    expect(simplified.isSimplifiedScore, isTrue);
    expect(simplified.scoreKindLabel, '简编谱');
  });
}
