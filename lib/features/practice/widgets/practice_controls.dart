import 'package:flutter/material.dart';

import '../../../shared/models/song.dart';
import '../../../shared/theme/app_theme.dart';
import '../practice_clock.dart';
import '../practice_models.dart';
import '../practice_stage_theme.dart';

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
    final stage = PracticeStageTheme.of(visualFxEnabled: s.visualFxEnabled);
    final baseTheme = Theme.of(context);
    final segmentStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(
        AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );

    return Theme(
      data: stage.applyTo(baseTheme),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
        decoration: BoxDecoration(
          color: stage.panelBg,
          border: Border(
            top: BorderSide(color: stage.panelBorder, width: 1.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transport
            Row(
              children: [
                _PlayPressScale(
                  child: IconButton.filled(
                    onPressed: onPlay,
                    tooltip: snap.isPlaying ? '暂停' : '播放',
                    style: IconButton.styleFrom(
                      backgroundColor: stage.accent,
                      foregroundColor: AppColors.onFill(stage.accent),
                      minimumSize: const Size(44, 44),
                    ),
                    icon: Icon(
                      snap.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onRestart,
                  tooltip: '重来',
                  icon: const Icon(Icons.replay_rounded),
                ),
                Expanded(
                  child: Semantics(
                    label: '进度',
                    slider: true,
                    enabled: s.mode.allowsSeek,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 11,
                            elevation: 2,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 22,
                          ),
                          activeTrackColor: stage.accent,
                          inactiveTrackColor:
                              stage.accent.withValues(alpha: 0.22),
                          thumbColor: stage.accent,
                          disabledThumbColor:
                              stage.accent.withValues(alpha: 0.45),
                          disabledActiveTrackColor:
                              stage.accent.withValues(alpha: 0.35),
                          disabledInactiveTrackColor:
                              stage.accent.withValues(alpha: 0.12),
                          overlayColor:
                              stage.accent.withValues(alpha: 0.18),
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                        child: SizedBox(
                          height: 44,
                          child: positionListenable == null
                              ? Slider(
                                  value: snap.positionBeats
                                      .clamp(0, snap.durationBeats),
                                  max: snap.durationBeats <= 0
                                      ? 1
                                      : snap.durationBeats,
                                  onChangeStart:
                                      s.mode.allowsSeek ? onSeek : null,
                                  onChanged:
                                      s.mode.allowsSeek ? onSeek : null,
                                )
                              : ListenableBuilder(
                                  listenable: positionListenable!,
                                  builder: (context, _) {
                                    final pos =
                                        positionListenable!.positionBeats;
                                    return Slider(
                                      value: pos.clamp(
                                        0,
                                        snap.durationBeats,
                                      ),
                                      max: snap.durationBeats <= 0
                                          ? 1
                                          : snap.durationBeats,
                                      onChangeStart: s.mode.allowsSeek
                                          ? onSeek
                                          : null,
                                      onChanged: s.mode.allowsSeek
                                          ? onSeek
                                          : null,
                                    );
                                  },
                                ),
                        ),
                      ),
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
                    style: AppTheme.body(fontSize: 11, color: stage.accent),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            // Mode + hand + 装饰特效（考试由 /exam 大厅进入，此处锁定）
            Row(
              children: [
                Expanded(
                  child: s.mode.isExam
                      ? Container(
                          height: 40,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: stage.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: stage.accent.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            '考试中 · 规则已锁定',
                            style: AppTheme.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: stage.accent,
                            ),
                          ),
                        )
                      : SegmentedButton<PracticeMode>(
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
                if (!s.mode.isExam) ...[
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
                const SizedBox(width: 8),
                _OptionChip(
                  label: '装饰特效',
                  selected: s.visualFxEnabled,
                  onSelected: (v) =>
                      onSettings(s.copyWith(visualFxEnabled: v)),
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
                            color: stage.accent,
                          ),
                        )
                      : s.mode.isAutoPlay
                          ? Text(
                              '自动播放中：按曲谱示范，无需跟弹',
                              style: AppTheme.body(
                                fontSize: 12,
                                color: stage.textSecondary,
                              ),
                            )
                          : snap.isLeadInRitual
                              ? Text(
                                  '开场准备',
                                  style: AppTheme.body(
                                    fontSize: 12,
                                    color: stage.accent,
                                  ),
                                )
                              : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
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
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      ),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.65)
            : Theme.of(context).colorScheme.outline,
      ),
      onSelected: onSelected,
    );
  }
}

/// Play button press scale — pointer-driven only (no idle AnimationController).
class _PlayPressScale extends StatefulWidget {
  const _PlayPressScale({required this.child});

  final Widget child;

  @override
  State<_PlayPressScale> createState() => _PlayPressScaleState();
}

class _PlayPressScaleState extends State<_PlayPressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
