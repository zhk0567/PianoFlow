import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/shared/models/song.dart';

/// Mirrors scripts/catalog_integrity_guard.py — catalog ↔ JSON ↔ MusicXML.
void main() {
  late final List<SongSummary> songs;
  late final Map<String, Map<String, dynamic>> scoresById;

  setUpAll(() {
    final catalog = jsonDecode(
      File('assets/scores/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    songs = (catalog['songs'] as List)
        .cast<Map<String, dynamic>>()
        .map(SongSummary.fromJson)
        .toList();
    scoresById = {};
    for (final s in songs) {
      final raw = File(s.asset).readAsStringSync();
      scoresById[s.id] = jsonDecode(raw) as Map<String, dynamic>;
    }
  });

  test('every catalog asset and packaged MusicXML exists', () {
    for (final s in songs) {
      expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
      final xml = File('assets/scores/musicxml/${s.id}.musicxml');
      final alt = File('assets/scores/musicxml/${s.id}.xml');
      expect(
        xml.existsSync() || alt.existsSync(),
        isTrue,
        reason: 'missing packaged MusicXML for ${s.id}',
      );
      final src = File('third_party/scores_musicxml/${s.id}.musicxml');
      final srcAlt = File('third_party/scores_musicxml/${s.id}.xml');
      final srcMxl = File('third_party/scores_musicxml/${s.id}.mxl');
      expect(
        src.existsSync() || srcAlt.existsSync() || srcMxl.existsSync(),
        isTrue,
        reason: 'missing third_party MusicXML for ${s.id}',
      );
    }
  });

  test('catalog id and bpm match score JSON', () {
    for (final s in songs) {
      final score = scoresById[s.id]!;
      expect(score['id'], s.id);
      expect(score['bpm'], s.bpm, reason: '${s.id} bpm drift');
    }
  });

  test('detects bpm drift between catalog summary and json', () {
    final s = songs.first;
    final drifted = SongSummary(
      id: s.id,
      title: s.title,
      artist: s.artist,
      genre: s.genre,
      difficulty: s.difficulty,
      bpm: s.bpm + 17,
      asset: s.asset,
      description: s.description,
      scoreKind: s.scoreKind,
    );
    final scoreBpm = scoresById[s.id]!['bpm'] as int;
    expect(drifted.bpm, isNot(scoreBpm));
  });

  test('catalog genres are covered by SongSummary.genreLabelsZh', () {
    for (final s in songs) {
      expect(
        SongSummary.genreLabelsZh.containsKey(s.genre),
        isTrue,
        reason: 'add UI map for genre ${s.genre} (${s.id})',
      );
    }
  });

  test('catalog scoreKind is formal|simplified|omrDraft', () {
    const allowed = {
      ScoreKind.formal,
      ScoreKind.simplified,
      ScoreKind.omrDraft,
    };
    for (final s in songs) {
      expect(allowed.contains(s.scoreKind), isTrue, reason: s.id);
    }
  });

  test('catalog difficulty is 1-5', () {
    for (final s in songs) {
      expect(s.difficulty, inInclusiveRange(1, 5), reason: s.id);
    }
  });

  test('catalog title/artist non-empty and score notes non-empty', () {
    for (final s in songs) {
      expect(s.title.trim(), isNotEmpty, reason: s.id);
      expect(s.artist.trim(), isNotEmpty, reason: s.id);
      final notes = scoresById[s.id]!['notes'] as List?;
      expect(notes, isNotNull, reason: s.id);
      expect(notes!, isNotEmpty, reason: s.id);
    }
  });

  test('catalog.asset path is assets/scores/<id>.json', () {
    for (final s in songs) {
      expect(s.asset, 'assets/scores/${s.id}.json');
    }
  });
}
