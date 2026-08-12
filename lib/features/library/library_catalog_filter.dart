import '../../shared/models/song.dart';

/// Pure catalog filters for the library shelf — unit-tested without widgets.
abstract final class LibraryCatalogFilter {
  static List<SongSummary> apply(
    List<SongSummary> songs, {
    String query = '',
    int? difficulty,
    String? genre,
    ScoreKind? scoreKind,
  }) {
    final q = query.trim().toLowerCase();
    return songs.where((s) {
      if (scoreKind != null && s.scoreKind != scoreKind) return false;
      if (difficulty != null && s.difficulty != difficulty) return false;
      if (genre != null && s.genre != genre) return false;
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q) ||
          s.genreLabelZh.toLowerCase().contains(q) ||
          s.scoreKindLabel.toLowerCase().contains(q) ||
          s.scoreKindLabelDetail.toLowerCase().contains(q) ||
          s.difficultyLabel.toLowerCase().contains(q);
    }).toList();
  }

  /// Chip labels for score-kind strip (null = 全部).
  /// Prefer [scoreKindChipsFor] so empty kinds (e.g. no simplified) stay hidden.
  static const scoreKindChips = <(ScoreKind?, String)>[
    (null, '全部谱种'),
    (ScoreKind.formal, '正式谱'),
    (ScoreKind.omrDraft, 'OMR草稿'),
    (ScoreKind.simplified, '简编谱'),
    (ScoreKind.userImport, '自导入'),
  ];

  /// Only kinds that appear in [songs], plus「全部谱种」.
  static List<(ScoreKind?, String)> scoreKindChipsFor(List<SongSummary> songs) {
    final present = {for (final s in songs) s.scoreKind};
    return [
      for (final chip in scoreKindChips)
        if (chip.$1 == null || present.contains(chip.$1)) chip,
    ];
  }

  static const difficultyLabels = <int, String>{
    1: '入门',
    2: '初级',
    3: '中级',
    4: '高级',
    5: '极难',
  };

  /// Catalog genre is often English (Classical/Anime); UI shows Chinese.
  static String genreLabelZh(String genre) => SongSummary.genreLabelsZh[genre] ?? genre;

  /// Difficulty chips present in [songs], plus「全部难度」.
  static List<(int?, String)> difficultyChipsFor(List<SongSummary> songs) {
    final levels = songs.map((s) => s.difficulty).toSet().toList()..sort();
    return [
      (null, '全部难度'),
      for (final d in levels) (d, difficultyLabels[d] ?? '难度$d'),
    ];
  }
}
