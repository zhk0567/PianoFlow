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

  test('detects formal mislabel for provenance id', () {
    final bad = SongSummary(
      id: 'hisaishi_castle_in_the_sky',
      title: '天空之城',
      artist: 'Joe Hisaishi',
      genre: '动画',
      difficulty: 3,
      bpm: 80,
      asset: 'assets/scores/x.json',
      description: 'test',
      scoreKind: ScoreKind.formal,
    );
    expect(ScoreKindPolicy.catalogViolations([bad]), isNotEmpty);
  });
}
