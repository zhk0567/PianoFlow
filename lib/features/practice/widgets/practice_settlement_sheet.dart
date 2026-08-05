import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../practice_exam_eval.dart';
import '../practice_models.dart';
import '../practice_settlement_copy.dart';

/// End-of-run settlement sheet (跟弹 / 考试整活).
Future<void> showPracticeSettlementSheet({
  required BuildContext context,
  required PracticeSnapshot snap,
  required VoidCallback onRetry,
  required VoidCallback onLeave,
  int songSessions = 0,
  String? examRecordingPath,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (ctx) {
      final title = PracticeSettlementCopy.title(
        perfects: snap.perfectCount,
        goods: snap.goodCount,
        misses: snap.sessionMisses,
        maxCombo: snap.maxCombo,
        songSessions: songSessions,
      );
      final subtitle = PracticeSettlementCopy.subtitle(
        perfects: snap.perfectCount,
        goods: snap.goodCount,
        misses: snap.sessionMisses,
      );
      final exam = snap.settings.mode.isExam
          ? PracticeExamEval.build(
              perfects: snap.perfectCount,
              goods: snap.goodCount,
              misses: snap.sessionMisses,
              maxCombo: snap.maxCombo,
              hitLog: [
                for (final h in snap.sessionHitLog)
                  (beat: h.beat, grade: h.grade),
              ],
            )
          : null;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (exam != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '考试得分 ${exam.score100.round()}',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    _StatChip(
                      label: HitGrade.perfect.labelZh ?? '完美',
                      value: '${snap.perfectCount}',
                      color: AppColors.success,
                    ),
                    _StatChip(
                      label: HitGrade.good.labelZh ?? '不错',
                      value: '${snap.goodCount}',
                      color: AppColors.accent,
                    ),
                    _StatChip(
                      label: '最高连击',
                      value: '${snap.maxCombo}',
                      color: AppColors.rightHand,
                    ),
                  ],
                ),
                if (exam != null) ...[
                  const SizedBox(height: 18),
                  _EvalBlock(title: '做得好', lines: exam.goods),
                  const SizedBox(height: 10),
                  _EvalBlock(title: '可以加强', lines: exam.improves),
                ],
                if (examRecordingPath != null &&
                    File(examRecordingPath).existsSync()) ...[
                  const SizedBox(height: 14),
                  _ExamListenButton(path: examRecordingPath),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onRetry();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.heroDeep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    snap.settings.mode.isExam ? '再考一次' : '再练一次',
                    style: AppTheme.body(
                      fontWeight: FontWeight.w700,
                      color: AppColors.heroDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onLeave();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    '回曲库',
                    style: AppTheme.body(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _EvalBlock extends StatelessWidget {
  const _EvalBlock({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $line',
                style: AppTheme.body(fontSize: 13, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExamListenButton extends StatefulWidget {
  const _ExamListenButton({required this.path});

  final String path;

  @override
  State<_ExamListenButton> createState() => _ExamListenButtonState();
}

class _ExamListenButtonState extends State<_ExamListenButton> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    await _player.play(DeviceFileSource(widget.path));
    setState(() => _playing = true);
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _toggle,
      icon: Icon(_playing ? Icons.stop_rounded : Icons.hearing_rounded),
      label: Text(_playing ? '停止聆听' : '聆听本场录音'),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: AppTheme.body(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.body(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
