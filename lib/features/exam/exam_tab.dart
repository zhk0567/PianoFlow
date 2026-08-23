import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';
import '../library/library_repository.dart';
import '../practice/practice_stats_store.dart';

/// 考试大厅：选曲开考、规则说明、本地战绩。开考复用 `/practice/:id?mode=exam`。
class ExamTab extends ConsumerStatefulWidget {
  const ExamTab({super.key});

  @override
  ConsumerState<ExamTab> createState() => _ExamTabState();
}

class _ExamTabState extends ConsumerState<ExamTab> {
  bool _record = true;
  String _query = '';
  String? _selectedId;

  List<SongSummary> _sortedForExam(List<SongSummary> songs) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? songs
        : songs.where((s) {
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q) ||
                s.scoreKindLabel.toLowerCase().contains(q);
          }).toList();
    filtered.sort((a, b) {
      final ka = _kindRank(a.scoreKind);
      final kb = _kindRank(b.scoreKind);
      if (ka != kb) return ka.compareTo(kb);
      return a.difficulty.compareTo(b.difficulty);
    });
    return filtered;
  }

  int _kindRank(ScoreKind k) => switch (k) {
        ScoreKind.formal => 0,
        ScoreKind.simplified => 1,
        ScoreKind.userImport => 2,
        ScoreKind.omrDraft => 3,
      };

  void _startExam(SongSummary song) {
    context.push(
      '/practice/${song.id}'
      '?mode=exam'
      '&record=${_record ? 1 : 0}'
      '&hand=both',
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final stats = ref.watch(practiceStatsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final padH = wide ? 32.0 : 20.0;

    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '曲库加载失败（详情见控制台 [PianoFlow/Library]）',
          style: AppTheme.body(color: AppColors.textSecondary),
        ),
      ),
      data: (songs) {
        final list = _sortedForExam(songs);
        SongSummary? selected;
        if (list.isNotEmpty) {
          selected = list.cast<SongSummary?>().firstWhere(
                (s) => s!.id == _selectedId,
                orElse: () => list.first,
              );
        }

        final examRows = stats.bySong.entries
            .where((e) => e.value.examSessions > 0)
            .toList()
          ..sort((a, b) => b.value.examSessions.compareTo(a.value.examSessions));
        final byId = {for (final s in songs) s.id: s};

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padH, wide ? 28 : 20, padH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '考试',
                      style: AppTheme.display(fontSize: wide ? 40 : 32),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '跟弹判定一场到底：不可拖进度、不可循环；结束后给出得分与评语。',
                      style: AppTheme.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _PrefsBar(
                      record: _record,
                      onRecord: (v) => setState(() => _record = v),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '选曲开考',
                      style: AppTheme.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: '搜索曲名或作曲家',
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padH, 14, padH, 8),
              sliver: SliverList.separated(
                itemCount: list.length.clamp(0, 40),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final song = list[i];
                  final sel = song.id == selected?.id;
                  final examN =
                      stats.bySong[song.id]?.examSessions ?? 0;
                  return _SongExamTile(
                    song: song,
                    selected: sel,
                    examSessions: examN,
                    onTap: () => setState(() => _selectedId = song.id),
                    onStart: () => _startExam(song),
                  );
                },
              ),
            ),
            if (list.length > 40)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, 0, padH, 8),
                  child: Text(
                    '仅显示前 40 首，可用搜索缩小范围',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padH, 16, padH, 8),
                child: Builder(
                  builder: (context) {
                    final song = selected;
                    return FilledButton.icon(
                      onPressed:
                          song == null ? null : () => _startExam(song),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        song == null
                            ? '请先选一首曲'
                            : '开始考试 · ${song.title}',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padH, 28, padH, 8),
                child: Text(
                  '考试战绩',
                  style: AppTheme.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (examRows.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, 4, padH, 8),
                  child: Text(
                    '还没有考试记录。选一首正式谱走完一遍，这里会出现场次与命中汇总。',
                    style: AppTheme.body(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padH, 4, padH, 8),
                sliver: SliverList.separated(
                  itemCount: examRows.length.clamp(0, 12),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = examRows[i];
                    final song = byId[e.key];
                    final st = e.value;
                    return _HistoryTile(
                      title: song?.title ?? e.key,
                      subtitle: song == null
                          ? '已考 ${st.examSessions} 场'
                          : '${song.artist} · 已考 ${st.examSessions} 场',
                      detail:
                          '完美 ${st.perfects} · 不错 ${st.goods} · 最高连击 ×${st.maxComboBest}',
                      onExamAgain: song == null
                          ? null
                          : () => _startExam(song),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padH, 24, padH, 40),
                child: const _RulesBlock(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PrefsBar extends StatelessWidget {
  const _PrefsBar({
    required this.record,
    required this.onRecord,
  });

  final bool record;
  final ValueChanged<bool> onRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '录制本次考试音频',
          style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '双手跟弹 · 麦克风 PCM 存本地，结算页可回听',
          style: AppTheme.body(fontSize: 12, color: AppColors.textMuted),
        ),
        value: record,
        onChanged: onRecord,
      ),
    );
  }
}

class _SongExamTile extends StatelessWidget {
  const _SongExamTile({
    required this.song,
    required this.selected,
    required this.examSessions,
    required this.onTap,
    required this.onStart,
  });

  final SongSummary song;
  final bool selected;
  final int examSessions;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${song.artist} · ${song.scoreKindLabel}'
                      '${examSessions > 0 ? ' · 已考 $examSessions 场' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onStart,
                child: const Text('开考'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.detail,
    this.onExamAgain,
  });

  final String title;
  final String subtitle;
  final String detail;
  final VoidCallback? onExamAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: AppTheme.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onExamAgain != null)
            TextButton(onPressed: onExamAgain, child: const Text('再考')),
        ],
      ),
    );
  }
}

class _RulesBlock extends StatelessWidget {
  const _RulesBlock();

  static const _rules = [
    '全程跟弹判定：弹对才推进，冻结时不可拖动进度条。',
    '禁止循环与示范音，避免「听着跟着过」冒充考试。',
    '可选录制麦克风 PCM，仅存本机，结算页可回听。',
    '正式谱优先；OMR 草稿也可考，但谱面可能不准，请诚实看待得分。',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '考试规则',
          style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _rules.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}.',
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _rules[i],
                  style: AppTheme.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
