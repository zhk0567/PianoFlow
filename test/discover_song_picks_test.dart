import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/home/discover_song_picks.dart';
import 'package:piano_flow/shared/models/song.dart';

SongSummary _s({
  required String id,
  required ScoreKind kind,
  int difficulty = 2,
  String title = '曲',
}) {
  return SongSummary(
    id: id,
    title: title,
    artist: 'A',
    genre: '古典',
    difficulty: difficulty,
    bpm: 100,
    asset: 'assets/scores/$id.json',
    description: '',
    scoreKind: kind,
  );
}

void main() {
  final omrEasy = _s(
    id: 'omr_easy',
    kind: ScoreKind.omrDraft,
    difficulty: 1,
    title: 'OMR入门',
  );
  final formalHard = _s(
    id: 'formal_hard',
    kind: ScoreKind.formal,
    difficulty: 3,
    title: '正式中级',
  );
  final simplified = _s(
    id: 'simp',
    kind: ScoreKind.simplified,
    difficulty: 1,
  );
  final furElise = _s(
    id: DiscoverSongPicks.preferredSongId,
    kind: ScoreKind.formal,
    difficulty: 2,
    title: 'Für Elise',
  );

  test('beginner prefers preferredSongId when present', () {
    expect(
      DiscoverSongPicks.beginner([omrEasy, furElise, formalHard])?.id,
      DiscoverSongPicks.preferredSongId,
    );
  });

  test('beginner prefers formal over easier OMR', () {
    expect(
      DiscoverSongPicks.beginner([omrEasy, formalHard])?.id,
      'formal_hard',
    );
  });

  test('beginner falls back to simplified before OMR', () {
    expect(
      DiscoverSongPicks.beginner([omrEasy, simplified])?.id,
      'simp',
    );
  });

  test('todaySong skips OMR when formal unplayed exists', () {
    final pick = DiscoverSongPicks.todaySong(
      [omrEasy, formalHard, simplified],
      {},
    );
    expect(pick?.id, 'formal_hard');
  });

  test('todaySong prefers preferred when unplayed', () {
    expect(
      DiscoverSongPicks.todaySong([omrEasy, furElise], {})?.id,
      DiscoverSongPicks.preferredSongId,
    );
  });

  test('todaySong among unplayed sorts formal then difficulty', () {
    final easyFormal = _s(
      id: 'f_easy',
      kind: ScoreKind.formal,
      difficulty: 1,
    );
    final pick = DiscoverSongPicks.todaySong(
      [omrEasy, formalHard, easyFormal],
      {DiscoverSongPicks.preferredSongId},
    );
    expect(pick?.id, 'f_easy');
  });

  test('todaySong all-played rotates only in best kind pool', () {
    final songs = [omrEasy, formalHard, simplified];
    final practiced = {for (final s in songs) s.id};
    final pick = DiscoverSongPicks.todaySong(
      songs,
      practiced,
      now: DateTime(2020, 1, 2),
    );
    expect(pick?.scoreKind, ScoreKind.formal);
    expect(pick?.id, 'formal_hard');
  });

  test('scoreKindRank formal < simplified < omrDraft', () {
    expect(DiscoverSongPicks.scoreKindRank(ScoreKind.formal), 0);
    expect(DiscoverSongPicks.scoreKindRank(ScoreKind.simplified), 1);
    expect(DiscoverSongPicks.scoreKindRank(ScoreKind.omrDraft), 2);
  });
}
