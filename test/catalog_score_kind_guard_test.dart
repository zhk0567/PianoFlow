import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/shared/models/song.dart';
import 'package:piano_flow/shared/score_kind_policy.dart';

void main() {
  late final Map<String, dynamic> catalog;
  late final Map<String, dynamic> policy;

  setUpAll(() {
    catalog = jsonDecode(
      File('assets/scores/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    policy = jsonDecode(
      File('assets/scores/score_kind_policy.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('Dart omrProvenanceIds matches score_kind_policy.json', () {
    final fromJson = (policy['omrProvenanceIds'] as List).cast<String>().toSet();
    expect(ScoreKindPolicy.omrProvenanceIds, fromJson);
  });

  test('catalog never marks OMR provenance as formal', () {
    final songs = (catalog['songs'] as List)
        .cast<Map<String, dynamic>>()
        .map(SongSummary.fromJson)
        .toList();
    final violations = ScoreKindPolicy.catalogViolations(songs);
    expect(violations, isEmpty, reason: violations.join('\n'));
    for (final id in ScoreKindPolicy.omrProvenanceIds) {
      final song = songs.firstWhere((s) => s.id == id);
      expect(song.scoreKind, ScoreKind.omrDraft);
      expect(song.isFormalScore, isFalse);
    }
  });

  test('detects formal with OMR-like description', () {
    final bad = SongSummary(
      id: 'some_new_piece',
      title: '新曲',
      artist: 'Unknown',
      genre: '动画',
      difficulty: 3,
      bpm: 80,
      asset: 'assets/scores/x.json',
      description: 'OMR draft from PDF via Audiveris.',
      scoreKind: ScoreKind.formal,
    );
    expect(ScoreKindPolicy.catalogViolations([bad]), isNotEmpty);
  });

  test('empty omrProvenanceIds allows all-formal catalog', () {
    expect(ScoreKindPolicy.omrProvenanceIds, isEmpty);
    final songs = (catalog['songs'] as List)
        .cast<Map<String, dynamic>>()
        .map(SongSummary.fromJson)
        .toList();
    expect(songs.every((s) => s.scoreKind == ScoreKind.formal), isTrue);
  });
}
