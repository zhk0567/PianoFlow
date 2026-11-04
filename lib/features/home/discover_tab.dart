import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breakpoint_latch.dart';
import '../library/library_repository.dart';
import '../library/user_library_store.dart';
import '../practice/practice_stats_store.dart';
import 'discover_song_picks.dart';
import 'widgets/home_sections.dart';
import 'widgets/soft_scaffold.dart';

class DiscoverTab extends ConsumerWidget {
  const DiscoverTab({super.key});

  /// Sole shipped demo / default practice target.
  static const preferredSongId = DiscoverSongPicks.preferredSongId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final library = ref.watch(userLibraryProvider);
    final stats = ref.watch(practiceStatsProvider);

    return WideBreakpointBuilder(
      enter: 900,
      exit: 860,
      builder: (context, wide) {
        return catalog.when(
            loading: () => const CustomScrollView(slivers: [SoftLoading()]),
            error: (e, _) => CustomScrollView(
              slivers: [
                SoftError(
                  message: '曲库加载失败（详情见控制台 [PianoFlow/Library]）',
                ),
              ],
            ),
            data: (songs) {
              final byId = {for (final s in songs) s.id: s};
              final recent = library.recent
                  .map((id) => byId[id])
                  .whereType<SongSummary>()
                  .toList();
              final favorites = library.favorites
                  .map((id) => byId[id])
                  .whereType<SongSummary>()
                  .toList();
              final continueSong = recent.isEmpty ? null : recent.first;
              final beginner = DiscoverSongPicks.beginner(songs);
              final today = DiscoverSongPicks.todaySong(
                songs,
                stats.bySong.keys.toSet(),
              );

              VoidCallback? onPrimary;
              if (continueSong != null) {
                onPrimary = () => context.push('/practice/${continueSong.id}');
              } else if (beginner != null) {
                onPrimary = () => context.push('/practice/${beginner.id}');
              } else {
                onPrimary = () => context.go('/library');
              }

              // post 延迟：先设收藏筛选再切 tab，避免首页收藏入口闪退回归。
              void openLibraryFavorites() {
                final enableFilter = favorites.isNotEmpty;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(libraryFavoritesOnlyProvider.notifier)
                      .setEnabled(enableFilter);
                  if (context.mounted) context.go('/library');
                });
              }

              final piece = continueSong ?? beginner;
              final cta = continueSong != null
                  ? '继续练习'
                  : (beginner != null ? '从这首开始' : '去曲库看看');
              final body = _PracticeHomeBody(
                wide: wide,
                piece: piece,
                cta: cta,
                onPrimary: onPrimary,
                recent: recent,
                favorites: favorites,
                today: today,
                onOpenLibraryFavorites: openLibraryFavorites,
              );

              // 窄屏：顶对齐单列，避免在手机高度里把卡片摊开。
              if (!wide) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: body),
                    ],
                  ),
                );
              }

              // 宽屏：整块在主区可用区域内水平、垂直居中；宽度仍封顶 1080。
              return LayoutBuilder(
                builder: (context, constraints) {
                  final minHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 0.0;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: body,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
      },
    );
  }
}

class _PracticeHomeBody extends StatelessWidget {
  const _PracticeHomeBody({
    required this.wide,
    required this.piece,
    required this.cta,
    required this.onPrimary,
    required this.recent,
    required this.favorites,
    required this.today,
    required this.onOpenLibraryFavorites,
  });

  final bool wide;
  final SongSummary? piece;
  final String cta;
  final VoidCallback? onPrimary;
  final List<SongSummary> recent;
  final List<SongSummary> favorites;
  final SongSummary? today;
  final VoidCallback onOpenLibraryFavorites;

  @override
  Widget build(BuildContext context) {
    final horizontal = wide ? 28.0 : 20.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, wide ? 28 : 20, horizontal, 0),
          child: Text(
            '练习',
            style: AppTheme.body(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 0),
          child: _ContinueCard(
            title: piece?.title ?? '还没有曲子',
            meta: piece?.homeHeroMetaLine ?? '去曲库选一首再开练',
            draft: piece?.isOmrDraft == true,
            cta: cta,
            onPressed: onPrimary,
            compact: !wide,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: HomeRecentList(
                          songs: recent,
                          fill: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            HomeFavoritesList(
                              songs: favorites,
                              onOpenLibraryFavorites: onOpenLibraryFavorites,
                            ),
                            const SizedBox(height: 16),
                            HomeTodaySong(song: today),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    HomeRecentList(songs: recent),
                    const SizedBox(height: 16),
                    HomeFavoritesList(
                      songs: favorites,
                      onOpenLibraryFavorites: onOpenLibraryFavorites,
                    ),
                    const SizedBox(height: 16),
                    HomeTodaySong(song: today),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.title,
    required this.meta,
    required this.draft,
    required this.cta,
    required this.onPressed,
    required this.compact,
  });

  final String title;
  final String meta;
  final bool draft;
  final String cta;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg);
    final body = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _copy(),
              const SizedBox(height: 16),
              _ContinueCta(label: cta, onPressed: onPressed),
            ],
          )
        : Row(
            children: [
              Expanded(child: _copy()),
              const SizedBox(width: 16),
              _ContinueCta(label: cta, onPressed: onPressed),
            ],
          );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.paper,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _copy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '现在练',
          style: AppTheme.body(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppTheme.body(
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          meta,
          style: AppTheme.body(
            fontSize: 14,
            color: draft ? AppColors.accentWarm : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// CTA with light press scale (matches former home_hero feel).
class _ContinueCta extends StatefulWidget {
  const _ContinueCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_ContinueCta> createState() => _ContinueCtaState();
}

class _ContinueCtaState extends State<_ContinueCta> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: FilledButton(
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}
