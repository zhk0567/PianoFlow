import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../practice_clock.dart';
import '../practice_constants.dart';
import '../practice_models.dart';
import 'visual_metronome.dart';

/// Bottom control strip for the practice page — transport / mode / options.
class PracticeControls extends StatelessWidget {
  const PracticeControls({
    super.key,
    required this.snap,
    required this.onPlay,
    required this.onRestart,
    required this.onSettings,
    required this.onSeek,
    this.positionListenable,
  });

  final PracticeSnapshot snap;
  final VoidCallback onPlay;
  final VoidCallback onRestart;
  final ValueChanged<PracticeSettings> onSettings;
  final ValueChanged<double> onSeek;

  /// When set, only the seek slider rebuilds at clock rate (not the whole strip).
  final PracticeClock? positionListenable;

  @override
  Widget build(BuildContext context) {
    final s = snap.settings;
    final segmentStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(
        AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Transport
          Row(
            children: [
              IconButton.filled(
                onPressed: onPlay,
                tooltip: snap.isPlaying ? '暂停' : '播放',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(44, 44),
                ),
                icon: Icon(
                  snap.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 26,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onRestart,
                tooltip: '重来',
                icon: const Icon(Icons.replay_rounded),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: positionListenable == null
                      ? Slider(
                          value: snap.positionBeats
                              .clamp(0, snap.durationBeats),
                          max: snap.durationBeats <= 0
                              ? 1
                              : snap.durationBeats,
                          onChanged: s.mode.allowsSeek ? onSeek : null,
                        )
                      : ListenableBuilder(
                          listenable: positionListenable!,
                          builder: (context, _) {
                            final pos = positionListenable!.positionBeats;
                            return Slider(
                              value: pos.clamp(0, snap.durationBeats),
                              max: snap.durationBeats <= 0
                                  ? 1
                                  : snap.durationBeats,
                              onChanged: s.mode.allowsSeek ? onSeek : null,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
          if (s.mode.isExam)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  snap.isLeadInRitual
                      ? '准备…'
                      : snap.endHangActive
                          ? '收束…'
                          : '考试中 · 不可拖动进度',
                  style: AppTheme.body(fontSize: 11, color: AppColors.accent),
                ),
              ),
            ),
          const SizedBox(height: 4),
          // Mode + hand（考试不是顶层模式，见下方「考试模式」开关）
          Row(
            children: [
              Expanded(
                child: SegmentedButton<PracticeMode>(
                  style: segmentStyle,
                  segments: const [
                    ButtonSegment(
                      value: PracticeMode.autoPlay,
                      label: Text('自动'),
                    ),
                    ButtonSegment(
                      value: PracticeMode.wait,
                      label: Text('练习'),
                    ),
                  ],
                  selected: {
                    s.mode.isAutoPlay
                        ? PracticeMode.autoPlay
                        : PracticeMode.wait,
                  },
                  onSelectionChanged: (v) {
                    final mode = v.first;
                    if (mode.isAutoPlay) {
                      onSettings(s.copyWith(
                        mode: PracticeMode.autoPlay,
                        guideAudio: true,
                      ));
                    } else {
                      onSettings(s.copyWith(
                        mode: PracticeMode.wait,
                        guideAudio: false,
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<Hand>(
                style: segmentStyle,
                segments: const [
                  ButtonSegment(
                    value: Hand.left,
                    label: Text('左'),
                    tooltip: '只练左手',
                  ),
                  ButtonSegment(
                    value: Hand.right,
                    label: Text('右'),
                    tooltip: '只练右手',
                  ),
                  ButtonSegment(
                    value: Hand.both,
                    label: Text('双'),
                    tooltip: '双手',
                  ),
                ],
                selected: {s.hand},
                onSelectionChanged: (v) =>
                    onSettings(s.copyWith(hand: v.first)),
              ),
            ],
          ),
          if (s.mode.isPractice) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '考试模式',
                  style: AppTheme.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: s.mode.isExam
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.85,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    value: s.mode.isExam,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (on) {
                      if (on) {
                        onSettings(s.copyWith(
                          mode: PracticeMode.exam,
                          guideAudio: false,
                          loopEnabled: false,
                        ));
                      } else {
                        onSettings(s.copyWith(mode: PracticeMode.wait));
                      }
                    },
                  ),
                ),
                if (s.mode.isExam) ...[
                  const SizedBox(width: 8),
                  _OptionChip(
                    label: '录制',
                    selected: s.examRecordAudio,
                    onSelected: (v) =>
                        onSettings(s.copyWith(examRecordAudio: v)),
                  ),
                  if (snap.ghostHits.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _OptionChip(
                      label: '残影',
                      selected: s.showGhost,
                      onSelected: (v) =>
                          onSettings(s.copyWith(showGhost: v)),
                    ),
                  ],
                ],
              ],
            ),
          ],
          const SizedBox(height: 4),
          // Speed + option chips
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '速度',
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                child: Text(
                  '${(s.speed * 100).round()}%',
                  style: AppTheme.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: s.speed,
                    min: PracticeConstants.speedMin,
                    max: PracticeConstants.speedMaxUi,
                    onChanged: (v) => onSettings(s.copyWith(speed: v)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                flex: 3,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (s.mode.isPractice && !s.mode.isExam) ...[
                        _OptionChip(
                          label: '示范音',
                          selected: s.guideAudio,
                          onSelected: (v) =>
                              onSettings(s.copyWith(guideAudio: v)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _OptionChip(
                        label: '节拍器',
                        selected: s.metronome,
                        onSelected: (v) =>
                            onSettings(s.copyWith(metronome: v)),
                      ),
                      const SizedBox(width: 4),
                      VisualMetronomeDot(
                        enabled: s.metronome,
                        isPlaying: snap.isPlaying,
                      ),
                      if (s.mode.allowsLoop) ...[
                        const SizedBox(width: 6),
                        _OptionChip(
                          label: '循环',
                          selected: s.loopEnabled,
                          onSelected: (v) =>
                              onSettings(s.copyWith(loopEnabled: v)),
                        ),
                      ],
                      const SizedBox(width: 6),
                      _OptionChip(
                        label: '装饰特效',
                        selected: s.visualFxEnabled,
                        onSelected: (v) =>
                            onSettings(s.copyWith(visualFxEnabled: v)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Volume — keep existing volume row below by matching next marker
          Row(
            children: [
              Text(
                '音量',
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                child: Text(
                  '${(s.volume * 100).round()}%',
                  style: AppTheme.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: s.volume.clamp(
                      PracticeConstants.volumeMin,
                      PracticeConstants.volumeMax,
                    ),
                    min: PracticeConstants.volumeMin,
                    max: PracticeConstants.volumeMax,
                    onChanged: (v) => onSettings(s.copyWith(volume: v)),
                  ),
                ),
              ),
              Icon(
                s.volume <= 0.001
                    ? Icons.volume_off_rounded
                    : s.volume < 0.4
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          if (s.mode.isPractice || s.mode.isAutoPlay)
            SizedBox(
              height: 22,
              child: Align(
                alignment: Alignment.centerLeft,
                child: s.mode.isPractice && snap.waitingFor.isNotEmpty
                    ? Text(
                        '请弹：${snap.waitingFor.map(_label).join(' · ')}',
                        style: AppTheme.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      )
                    : s.mode.isAutoPlay
                        ? Text(
                            '自动播放中：按曲谱示范，无需跟弹',
                            style: AppTheme.body(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : snap.isLeadInRitual
                            ? Text(
                                '开场准备',
                                style: AppTheme.body(
                                  fontSize: 12,
                                  color: AppColors.accent,
                                ),
                              )
                            : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  String _label(int midi) {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    return '${names[midi % 12]}${(midi ~/ 12) - 1}';
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: AppTheme.body(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? AppColors.accent : AppColors.textSecondary,
      ),
      selectedColor: AppColors.accentSoft,
      backgroundColor: AppColors.surfaceAlt,
      side: BorderSide(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.45)
            : AppColors.border,
      ),
      onSelected: onSelected,
    );
  }
}
