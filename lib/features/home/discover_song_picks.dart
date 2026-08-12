import '../../shared/models/song.dart';

/// Discover-tab entry picks — prefer formal scores over OMR drafts.
abstract final class DiscoverSongPicks {
  /// Sole shipped demo / default practice target (formal MusicXML).
  static const preferredSongId = 'fur_elise_woo59';

  /// Lower rank = better for hero / 「今日」入口.
  static int scoreKindRank(ScoreKind kind) => switch (kind) {
        ScoreKind.formal => 0,
        ScoreKind.simplified => 1,
        ScoreKind.userImport => 2,
        ScoreKind.omrDraft => 3,
      };

  static int compareForEntry(SongSummary a, SongSummary b) {
    final byKind =
        scoreKindRank(a.scoreKind).compareTo(scoreKindRank(b.scoreKind));
    if (byKind != 0) return byKind;
    return a.difficulty.compareTo(b.difficulty);
  }

  static SongSummary? byId(List<SongSummary> songs, String id) {
    for (final s in songs) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Songs in the best available quality tier (formal if any, else simplified, else OMR).
  static List<SongSummary> bestKindPool(List<SongSummary> songs) {
    if (songs.isEmpty) return const [];
    var best = scoreKindRank(songs.first.scoreKind);
    for (final s in songs) {
      final r = scoreKindRank(s.scoreKind);
      if (r < best) best = r;
    }
    return songs.where((s) => scoreKindRank(s.scoreKind) == best).toList();
  }

  static SongSummary? beginner(List<SongSummary> songs) {
    final preferred = byId(songs, preferredSongId);
    if (preferred != null) return preferred;
    if (songs.isEmpty) return null;
    final ranked = [...songs]..sort(compareForEntry);
    return ranked.first;
  }

  static SongSummary? todaySong(
    List<SongSummary> songs,
    Set<String> practicedIds, {
    DateTime? now,
  }) {
    if (songs.isEmpty) return null;
    final preferred = byId(songs, preferredSongId);
    if (preferred != null && !practicedIds.contains(preferred.id)) {
      return preferred;
    }
    final unplayed = songs.where((s) => !practicedIds.contains(s.id)).toList()
      ..sort(compareForEntry);
    if (unplayed.isNotEmpty) return unplayed.first;
    if (preferred != null) return preferred;
    final pool = bestKindPool(songs);
    final dayIndex =
        (now ?? DateTime.now()).difference(DateTime(2020, 1, 1)).inDays.abs();
    return pool[dayIndex % pool.length];
  }
}
