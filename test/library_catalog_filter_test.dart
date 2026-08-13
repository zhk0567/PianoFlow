import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/features/library/library_catalog_filter.dart';
import 'package:piano_flow/shared/models/song.dart';

SongSummary _s({
  required String id,
  required ScoreKind kind,
  int difficulty = 1,
  String genre = '古典',
  String title = '曲',
}) {
  return SongSummary(
    id: id,
    title: title,
    artist: 'A',
    genre: genre,
    difficulty: difficulty,
    bpm: 100,
    asset: 'assets/scores/$id.json',
    description: '',
    scoreKind: kind,
  );
}

void main() {
  final songs = [
    _s(id: 'f', kind: ScoreKind.formal, title: 'Fur Elise'),
    _s(id: 'o', kind: ScoreKind.omrDraft, title: '天空之城', genre: '动画'),
    _s(id: 'j', kind: ScoreKind.simplified, difficulty: 2, title: '简编示例'),
  ];

  test('null scoreKind keeps all', () {
    expect(LibraryCatalogFilter.apply(songs).length, 3);
  });

  test('filters by formal / omrDraft / simplified', () {
    expect(
      LibraryCatalogFilter.apply(songs, scoreKind: ScoreKind.formal)
          .map((s) => s.id),
      ['f'],
    );
    expect(
      LibraryCatalogFilter.apply(songs, scoreKind: ScoreKind.omrDraft)
          .map((s) => s.id),
      ['o'],
    );
    expect(
      LibraryCatalogFilter.apply(songs, scoreKind: ScoreKind.simplified)
          .map((s) => s.id),
      ['j'],
    );
  });

  test('combines scoreKind with difficulty and query', () {
    final mixed = [
      ...songs,
      _s(
        id: 'f2',
        kind: ScoreKind.formal,
        difficulty: 3,
        title: 'Canon',
      ),
    ];
    expect(
      LibraryCatalogFilter.apply(
        mixed,
        scoreKind: ScoreKind.formal,
        difficulty: 3,
      ).map((s) => s.id),
      ['f2'],
    );
    expect(
      LibraryCatalogFilter.apply(mixed, query: '天空').map((s) => s.id),
      ['o'],
    );
    expect(
      LibraryCatalogFilter.apply(mixed, query: '正式').map((s) => s.id),
      ['f', 'f2'],
    );
    expect(
      LibraryCatalogFilter.apply(mixed, query: '未校对').map((s) => s.id),
      ['o'],
    );
  });

  test('scoreKindChips cover all + each kind', () {
    expect(LibraryCatalogFilter.scoreKindChips.length, 5);
    expect(
      LibraryCatalogFilter.scoreKindChips.map((e) => e.$2).toList(),
      ['全部谱种', '正式谱', 'OMR草稿', '简编谱', '自导入'],
    );
  });

  test('scoreKindChipsFor hides kinds absent from catalog', () {
    final noSimplified = songs.where((s) => s.scoreKind != ScoreKind.simplified);
    expect(
      LibraryCatalogFilter.scoreKindChipsFor(noSimplified.toList())
          .map((e) => e.$2)
          .toList(),
      ['全部谱种', '正式谱', 'OMR草稿'],
    );
    expect(
      LibraryCatalogFilter.scoreKindChipsFor(const []).map((e) => e.$2).toList(),
      ['全部谱种'],
    );
  });

  test('difficultyChipsFor only lists present levels', () {
    final mixed = [
      _s(id: 'a', kind: ScoreKind.formal, difficulty: 2),
      _s(id: 'b', kind: ScoreKind.omrDraft, difficulty: 5),
      _s(id: 'c', kind: ScoreKind.formal, difficulty: 3),
    ];
    expect(
      LibraryCatalogFilter.difficultyChipsFor(mixed).map((e) => e.$2).toList(),
      ['全部难度', '初级', '中级', '极难'],
    );
  });

  test('genre chips and query use Chinese labels', () {
    expect(LibraryCatalogFilter.genreLabelZh('Anime'), '动画');
    expect(LibraryCatalogFilter.genreLabelZh('Classical'), '古典');
    expect(
      _s(id: 'o', kind: ScoreKind.omrDraft, genre: 'Anime').genreLabelZh,
      '动画',
    );
    final anime = [
      _s(id: 'o', kind: ScoreKind.omrDraft, title: '天空之城', genre: 'Anime'),
    ];
    expect(
      LibraryCatalogFilter.apply(anime, query: '动画').map((s) => s.id),
      ['o'],
    );
  });

  test('query matches difficultyLabel', () {
    final hard = [
      _s(id: 'h', kind: ScoreKind.formal, difficulty: 5, title: '大黄蜂'),
    ];
    expect(
      LibraryCatalogFilter.apply(hard, query: '极难').map((s) => s.id),
      ['h'],
    );
  });
}
