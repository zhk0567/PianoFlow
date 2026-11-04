import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/ui_bits.dart';

/// Panel with solid surface + border so song blocks stay readable on the hero glow.
class _HomePanel extends StatelessWidget {
  const _HomePanel({required this.child, this.fill = false});

  final Widget child;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: fill ? double.infinity : null,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: child,
    );
  }
}

class HomeRecentList extends StatelessWidget {
  const HomeRecentList({super.key, required this.songs, this.fill = false});

  final List<SongSummary> songs;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _HomePanel(
        fill: fill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('最近练习'),
            const SizedBox(height: 10),
            Text(
              '还没有练习记录。点上方按钮开练第一首。',
              style: AppTheme.body(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final items = songs.take(3).toList();
    return _HomePanel(
      fill: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '最近练习',
            trailing: TextButton(
              onPressed: () => context.go('/library'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '曲库',
                style: AppTheme.body(
                  fontSize: 13,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(items.length, (i) {
            final s = items[i];
            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                InkWell(
                  onTap: () => context.push('/practice/${s.id}'),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: AppTheme.body(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.homeRecentMetaLine,
                                style: AppTheme.body(
                                  fontSize: 13,
                                  color: s.isOmrDraft
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '练',
                          style: AppTheme.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// 首页「我的收藏」：空态引导；有收藏可点进曲库并打开收藏筛选。
class HomeFavoritesList extends StatelessWidget {
  const HomeFavoritesList({
    super.key,
    required this.songs,
    required this.onOpenLibraryFavorites,
    this.fill = false,
  });

  final List<SongSummary> songs;
  final VoidCallback onOpenLibraryFavorites;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _HomePanel(
        fill: fill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              '我的收藏',
              trailing: TextButton(
                onPressed: onOpenLibraryFavorites,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '去收藏',
                  style: AppTheme.body(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '暂无收藏。曲库封面点右上角星标即可收藏。',
              style: AppTheme.body(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final items = songs.take(3).toList();
    return _HomePanel(
      fill: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '我的收藏',
            trailing: TextButton(
              onPressed: onOpenLibraryFavorites,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '全部',
                style: AppTheme.body(
                  fontSize: 13,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(items.length, (i) {
            final s = items[i];
            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                InkWell(
                  onTap: () => context.push('/practice/${s.id}'),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: AppTheme.body(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.homeRecentMetaLine,
                                style: AppTheme.body(
                                  fontSize: 13,
                                  color: s.isOmrDraft
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class HomeTodaySong extends StatefulWidget {
  const HomeTodaySong({super.key, required this.song, this.fill = false});

  final SongSummary? song;
  final bool fill;

  @override
  State<HomeTodaySong> createState() => _HomeTodaySongState();
}

class _HomeTodaySongState extends State<HomeTodaySong>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    if (song == null) return const SizedBox.shrink();

    return _HomePanel(
      fill: widget.fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('今日一首'),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => context.push('/practice/${song.id}'),
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final t = _pulse.value;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.35 + t * 0.55),
                                  width: 2,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.only(bottom: 4),
                            child: child,
                          );
                        },
                        child: Text(
                          song.title,
                          style: AppTheme.display(
                            fontSize: 24,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.homeTodayMetaLine,
                        style: AppTheme.body(
                          fontSize: 14,
                          color: song.isOmrDraft
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => context.push('/practice/${song.id}'),
                  child: const Text('开练'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
