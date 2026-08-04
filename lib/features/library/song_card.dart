import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';
import 'user_library_store.dart';

/// 「唱片」封面卡：大图 + 底部叠字 + 角上收藏。
class RecordAlbumCard extends ConsumerWidget {
  const RecordAlbumCard({super.key, required this.song});

  final SongSummary song;

  /// Stable accent pair from song id (visual variety without “random” feel).
  (Color, Color) _ink(String id) {
    const pairs = <(Color, Color)>[
      (Color(0xFFE8A849), Color(0xFF2A2118)),
      (Color(0xFF6DB3F2), Color(0xFF152030)),
      (Color(0xFFF2A06D), Color(0xFF2A1A12)),
      (Color(0xFF5CBF8A), Color(0xFF122018)),
      (Color(0xFFB08CFF), Color(0xFF1A1528)),
      (Color(0xFFE26A6A), Color(0xFF281414)),
      (Color(0xFF7EC8E3), Color(0xFF122028)),
      (Color(0xFFD4A574), Color(0xFF241810)),
    ];
    return pairs[id.hashCode.abs() % pairs.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(userLibraryProvider).favorites.contains(song.id);
    final ink = _ink(song.id);
    final hue = ink.$1;
    final deep = ink.$2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push('/practice/${song.id}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.borderSubtle),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(hue, deep, 0.15)!,
                deep,
                Color.lerp(deep, Colors.black, 0.35)!,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Decorative “vinyl / staff” motif.
              Positioned(
                right: -20,
                top: -10,
                child: Opacity(
                  opacity: 0.14,
                  child: Icon(
                    switch (song.scoreKind) {
                      ScoreKind.formal => Icons.menu_book_rounded,
                      ScoreKind.omrDraft => Icons.document_scanner_rounded,
                      ScoreKind.simplified => Icons.album_rounded,
                    },
                    size: 140,
                    color: hue,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    song.difficultyLabel,
                    style: AppTheme.body(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hue,
                    ),
                  ),
                ),
              ),
              // Bottom title band.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadii.lg - 1),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${song.artist} · ${song.bpm} BPM'
                        ' · ${song.scoreKindLabelDetail}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: 12,
                          color: song.isOmrDraft
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: fav ? '取消收藏' : '收藏',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(userLibraryProvider.notifier)
                        .toggleFavorite(song.id),
                    icon: Icon(
                      fav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: fav ? AppColors.accent : Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legacy name — same as [RecordAlbumCard].
class SongCard extends ConsumerWidget {
  const SongCard({super.key, required this.song});

  final SongSummary song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RecordAlbumCard(song: song);
  }
}
