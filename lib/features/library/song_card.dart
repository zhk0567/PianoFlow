import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/piano_flow_log.dart';
import '../../shared/theme/app_theme.dart';
import 'library_repository.dart';
import 'user_import_store.dart';
import 'user_library_store.dart';

/// 「唱片」封面卡：大图 + 底部叠字 + 角上收藏。
class RecordAlbumCard extends ConsumerWidget {
  const RecordAlbumCard({super.key, required this.song});

  final SongSummary song;

  /// Warm-paper accent wash from song id (Echo family — readable on page bg).
  (Color, Color) _wash(String id) {
    const pairs = <(Color, Color)>[
      // sage → tinted cream
      (Color(0xFFB5CFA0), Color(0xFFE8F0DC)),
      // walnut → tinted cream
      (Color(0xFFD4B090), Color(0xFFF0E4D4)),
      // soft peach → tinted cream
      (Color(0xFFE0B090), Color(0xFFF2E2D4)),
      // soft teal → tinted cream
      (Color(0xFF9CBCBC), Color(0xFFDCE8E8)),
      // olive → tinted cream
      (Color(0xFFC0C890), Color(0xFFE8EAD8)),
      // clay → tinted cream
      (Color(0xFFD0A890), Color(0xFFF0E0D4)),
      // sand → tinted cream
      (Color(0xFFD0BC90), Color(0xFFF0E8D4)),
      // moss → tinted cream
      (Color(0xFFA0BC9C), Color(0xFFDCE8D8)),
    ];
    return pairs[id.hashCode.abs() % pairs.length];
  }

  /// Stronger ink for motif / chip — still on-theme.
  Color _accentFor(String id) {
    const accents = <Color>[
      AppColors.accent,
      AppColors.accentWarm,
      AppColors.leftHand,
      AppColors.rightHand,
      Color(0xFF5A6E48),
      Color(0xFF8A6448),
      Color(0xFF6B6258),
      Color(0xFF4A7A54),
    ];
    return accents[id.hashCode.abs() % accents.length];
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除自导入？'),
        content: Text(
          '将删除「${song.title}」及其本地 JSON / MusicXML。曲库打包曲目不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await UserImportStore().deleteUserScore(song.id);
      await ref.read(userLibraryProvider.notifier).forgetSong(song.id);
      ref.invalidate(catalogProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除「${song.title}」')),
      );
    } catch (e, st) {
      pianoFlowLog('Library', 'delete userImport failed: $e\n$st');
      if (!context.mounted) return;
      final msg = e is StateError ? e.message : '删除失败：$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(userLibraryProvider).favorites.contains(song.id);
    final wash = _wash(song.id);
    final top = wash.$1;
    final bottom = wash.$2;
    final accent = _accentFor(song.id);
    final canDelete = song.isUserImport;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push('/practice/${song.id}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: fav
                  ? AppColors.accent.withValues(alpha: 0.9)
                  : const Color(0xFFC4B6A4),
              width: fav ? 2 : 1.25,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom, AppColors.paper],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: fav
                    ? AppColors.accent.withValues(alpha: 0.22)
                    : const Color(0x281F1A16),
                blurRadius: fav ? 16 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Decorative motif — soft on paper.
              Positioned(
                right: -20,
                top: -10,
                child: Opacity(
                  opacity: 0.28,
                  child: Icon(
                    switch (song.scoreKind) {
                      ScoreKind.formal => Icons.menu_book_rounded,
                      ScoreKind.omrDraft => Icons.document_scanner_rounded,
                      ScoreKind.simplified => Icons.album_rounded,
                      ScoreKind.userImport => Icons.upload_file_rounded,
                    },
                    size: 140,
                    color: accent,
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
                    color: AppColors.accentSoft.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    song.difficultyLabel,
                    style: AppTheme.body(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              // Bottom title band — paper fade, dark ink.
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
                        bottom.withValues(alpha: 0),
                        AppColors.paper.withValues(alpha: 0.94),
                        AppColors.paper,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: fav
                          ? AppColors.accentSoft
                          : AppColors.surface.withValues(alpha: 0.88),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: fav ? '取消收藏' : '收藏',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref
                            .read(userLibraryProvider.notifier)
                            .toggleFavorite(song.id),
                        icon: Icon(
                          fav
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: fav
                              ? AppColors.accent
                              : AppColors.textMuted,
                          size: fav ? 24 : 22,
                        ),
                      ),
                    ),
                    if (canDelete) ...[
                      const SizedBox(height: 4),
                      Material(
                        color: AppColors.surface.withValues(alpha: 0.88),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: '删除自导入',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmDelete(context, ref),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger.withValues(alpha: 0.85),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (fav)
                Positioned(
                  left: 16,
                  top: 48,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '已收藏',
                      style: AppTheme.body(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onAccent,
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
