import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breakpoint_latch.dart';
import '../library/library_repository.dart';
import '../library/user_library_store.dart';
import '../practice/practice_stats_store.dart';
import 'widgets/home_atmosphere.dart';
import 'widgets/home_hero.dart';
import 'widgets/home_sections.dart';
import 'widgets/soft_scaffold.dart';

class DiscoverTab extends ConsumerWidget {
  const DiscoverTab({super.key});

  /// Sole shipped demo / default practice target.
  static const preferredSongId = 'fur_elise_woo59';

  static SongSummary? _byId(List<SongSummary> songs, String id) {
    for (final s in songs) {
      if (s.id == id) return s;
    }
    return null;
  }

  static SongSummary? _beginner(List<SongSummary> songs) {
    final preferred = _byId(songs, preferredSongId);
    if (preferred != null) return preferred;
    final easy = songs.where((s) => s.difficulty <= 1).toList();
    if (easy.isNotEmpty) return easy.first;
    return songs.isEmpty ? null : songs.first;
  }

  static SongSummary? _todaySong(
    List<SongSummary> songs,
    Set<String> practicedIds,
  ) {
    if (songs.isEmpty) return null;
    final preferred = _byId(songs, preferredSongId);
    if (preferred != null && !practicedIds.contains(preferred.id)) {
      return preferred;
    }
    final unplayed = songs.where((s) => !practicedIds.contains(s.id)).toList()
      ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
    if (unplayed.isNotEmpty) return unplayed.first;
    if (preferred != null) return preferred;
    final dayIndex =
        DateTime.now().difference(DateTime(2020, 1, 1)).inDays.abs();
    return songs[dayIndex % songs.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final library = ref.watch(userLibraryProvider);
    final stats = ref.watch(practiceStatsProvider);

    return WideBreakpointBuilder(
      enter: 900,
      exit: 860,
      builder: (context, wide) {
        final size = MediaQuery.sizeOf(context);
        final heroMin =
            (size.height * (wide ? 0.48 : 0.42)).clamp(260.0, 520.0);

        return HomeAtmosphere(
          child: catalog.when(
            loading: () => const CustomScrollView(slivers: [SoftLoading()]),
            error: (e, _) => CustomScrollView(
              slivers: [SoftError(message: '加载失败：$e')],
            ),
            data: (songs) {
              final byId = {for (final s in songs) s.id: s};
              final recent = library.recent
                  .map((id) => byId[id])
                  .whereType<SongSummary>()
                  .toList();
              final continueSong = recent.isEmpty ? null : recent.first;
              final beginner = _beginner(songs);
              final today = _todaySong(songs, stats.bySong.keys.toSet());

              VoidCallback? onPrimary;
              if (continueSong != null) {
                onPrimary = () => context.push('/practice/${continueSong.id}');
              } else if (beginner != null) {
                onPrimary = () => context.push('/practice/${beginner.id}');
              } else {
                onPrimary = () => context.go('/library');
              }

              final horizontal = wide ? 48.0 : 20.0;
              final maxW = wide ? AppLayout.homeMaxWidth : double.infinity;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: horizontal),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HomeHero(
                                continueSong: continueSong,
                                beginnerSong: beginner,
                                onPrimary: onPrimary,
                                minHeight: heroMin,
                                wide: wide,
                              ),
                              if (wide)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 48),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: HomeRecentList(
                                            songs: recent,
                                            fill: true,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: HomeTodaySong(
                                            song: today,
                                            fill: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                const SizedBox(height: 8),
                                HomeRecentList(songs: recent),
                                const SizedBox(height: 16),
                                HomeTodaySong(song: today),
                                const SizedBox(height: 40),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
