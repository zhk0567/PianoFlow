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

  test('SongSummary reads scoreKind formal / simplified / omrDraft', () {
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
    final omr = SongSummary.fromJson({
      'id': 'c',
      'title': 'T',
      'artist': 'A',
      'genre': '流行',
      'difficulty': 3,
      'bpm': 80,
      'asset': 'assets/scores/c.json',
      'scoreKind': 'omrDraft',
    });
    expect(formal.scoreKind, ScoreKind.formal);
    expect(formal.isFormalScore, isTrue);
    expect(formal.scoreKindLabel, '正式谱');
    expect(simplified.isSimplifiedScore, isTrue);
    expect(simplified.scoreKindLabel, '简编谱');
    expect(omr.isOmrDraft, isTrue);
    expect(omr.isFormalScore, isFalse);
    expect(omr.scoreKindLabel, 'OMR草稿');
    expect(omr.scoreKindLabelDetail, 'OMR草稿（未校对）');
    expect(formal.scoreKindLabelDetail, '正式谱');
    expect(
      formal.homeTodayMetaLine,
      'A · 正式谱 · 入门 · 100 BPM',
    );
    expect(
      omr.homeRecentMetaLine,
      'OMR草稿（未校对） · 中级 · 80 BPM',
    );
    expect(
      omr.homeHeroMetaLine,
      'A · OMR草稿（未校对） · 中级',
    );
    expect(omr.practiceHonestyBanner, SongSummary.omrHonestyNotice);
    expect(formal.practiceHonestyBanner, isNull);
    expect(
      SongSummary(
        id: 'u',
        title: 'u',
        artist: 'a',
        genre: 'g',
        difficulty: 3,
        bpm: 100,
        asset: 'a',
        description: '自导入；仅前 45 秒预览（完整曲目未转录）',
        scoreKind: ScoreKind.userImport,
      ).practiceHonestyBanner,
      contains('前 45 秒音频预览'),
    );
    expect(
      SongSummary(
        id: 'x',
        title: 'x',
        artist: 'a',
        genre: 'g',
        difficulty: 5,
        bpm: 100,
        asset: 'a',
        description: '',
      ).difficultyLabel,
      '极难',
    );
    expect(
      SongSummary.omrHonestyNotice,
      contains('未经逐音校对'),
    );
  });
}
