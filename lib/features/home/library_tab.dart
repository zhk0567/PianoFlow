import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/ui_bits.dart';
import '../library/library_repository.dart';
import '../library/song_card.dart';
import '../practice/verovio_runtime.dart';

/// Library — 「唱片架」：大标题、横滑筛选、宽幅封面网格。
class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  String _query = '';
  /// null = 全部难度；1–4 = 入门…高级
  int? _difficulty;
  /// null = 全部风格
  String? _genre;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      VerovioRuntime.instance.prewarm();
    }
  }

  List<SongSummary> _filter(List<SongSummary> songs) {
    final q = _query.toLowerCase();
    return songs.where((s) {
      if (_difficulty != null && s.difficulty != _difficulty) return false;
      if (_genre != null && s.genre != _genre) return false;
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('$e', style: AppTheme.body(color: AppColors.textSecondary)),
      ),
      data: (songs) {
        final genres = songs.map((s) => s.genre).toSet().toList()..sort();
        final filtered = _filter(songs);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 32 : 20,
                  wide ? 28 : 20,
                  wide ? 32 : 20,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('曲库', style: AppTheme.display(fontSize: wide ? 40 : 32)),
                    const SizedBox(height: 6),
                    Text(
                      '挑一张，直接开练',
                      style: AppTheme.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: '搜索曲名、作曲家或风格',
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 16),
                    _FilterStrip(
                      difficulty: _difficulty,
                      genre: _genre,
                      genres: genres,
                      onDifficulty: (v) => setState(() => _difficulty = v),
                      onGenre: (v) => setState(() => _genre = v),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      filtered.isEmpty
                          ? '无匹配曲目'
                          : '${filtered.length} 张唱片',
                      style: AppTheme.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(message: '没有匹配的曲目，试试换个筛选或关键词'),
              )
            else
              RecordShelfGrid(songs: filtered, wide: wide),
          ],
        );
      },
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.difficulty,
    required this.genre,
    required this.genres,
    required this.onDifficulty,
    required this.onGenre,
  });

  final int? difficulty;
  final String? genre;
  final List<String> genres;
  final ValueChanged<int?> onDifficulty;
  final ValueChanged<String?> onGenre;

  static const _diffLabels = <(int?, String)>[
    (null, '全部难度'),
    (1, '入门'),
    (2, '初级'),
    (3, '中级'),
    (4, '高级'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (value, label) in _diffLabels) ...[
                _ShelfChip(
                  label: label,
                  selected: difficulty == value,
                  onTap: () => onDifficulty(value),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ShelfChip(
                  label: '全部风格',
                  selected: genre == null,
                  onTap: () => onGenre(null),
                ),
                const SizedBox(width: 8),
                for (final g in genres) ...[
                  _ShelfChip(
                    label: g,
                    selected: genre == g,
                    onTap: () => onGenre(g),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ShelfChip extends StatelessWidget {
  const _ShelfChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.borderSubtle,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class RecordShelfGrid extends StatelessWidget {
  const RecordShelfGrid({
    super.key,
    required this.songs,
    required this.wide,
  });

  final List<SongSummary> songs;
  final bool wide;

  static int columnsForWidth(double width) {
    if (width < 420) return 1;
    if (width < 720) return 2;
    if (width < 1100) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    final hPad = wide ? 32.0 : 20.0;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 40),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final cols = columnsForWidth(constraints.crossAxisExtent);
          // Nearly square album covers — title overlays bottom, no extra text block.
          final aspect = cols == 1 ? 1.15 : 1.0;

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: aspect,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => RecordAlbumCard(song: songs[index]),
              childCount: songs.length,
            ),
          );
        },
      ),
    );
  }
}

/// Kept for any old call sites; forwards to [RecordShelfGrid].
class SoftSongList extends StatelessWidget {
  const SoftSongList({super.key, required this.songs, this.title = '曲目列表'});

  final List<SongSummary> songs;
  final String title;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return RecordShelfGrid(songs: songs, wide: wide);
  }
}
