import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../score_audio_player.dart';

/// Compact beat pulse next to the metronome toggle — same clock as audio clicks.
class VisualMetronomeDot extends ConsumerStatefulWidget {
  const VisualMetronomeDot({
    super.key,
    required this.enabled,
    required this.isPlaying,
  });

  final bool enabled;
  final bool isPlaying;

  @override
  ConsumerState<VisualMetronomeDot> createState() => _VisualMetronomeDotState();
}

class _VisualMetronomeDotState extends ConsumerState<VisualMetronomeDot>
    with SingleTickerProviderStateMixin {
  StreamSubscription<MetronomeTick>? _sub;
  late final AnimationController _pulse;
  MetronomeTick? _last;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _bind();
  }

  @override
  void didUpdateWidget(covariant VisualMetronomeDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || !widget.isPlaying) {
      _pulse.value = 0;
      _last = null;
    }
    if (oldWidget.enabled != widget.enabled) {
      _bind();
    }
  }

  void _bind() {
    _sub?.cancel();
    _sub = null;
    if (!widget.enabled) return;
    final audio = ref.read(scoreAudioProvider);
    _sub = audio.metronomeTickStream.listen(_onTick);
  }

  void _onTick(MetronomeTick tick) {
    if (!mounted || !widget.enabled || !widget.isPlaying) return;
    setState(() => _last = tick);
    // Snap attack, decay over ~half beat (capped) so slow tempos stay readable.
    final ms = (tick.period.inMilliseconds * 0.45).round().clamp(90, 360);
    _pulse.duration = Duration(milliseconds: ms);
    _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final running = widget.isPlaying;
    final accent = _last?.accent ?? true;
    final beatLabel = _last?.beatInBar() ?? 1;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        // Attack at tick (t=0), decay over the beat period.
        final t = running ? (1.0 - _pulse.value).clamp(0.0, 1.0) : 0.0;
        final scale = running ? 1.0 + (accent ? 0.28 : 0.14) * t : 1.0;
        final scheme = Theme.of(context).colorScheme;
        final color = !running
            ? scheme.outline
            : Color.lerp(
                accent ? scheme.primaryContainer : scheme.outline,
                scheme.primary,
                t,
              )!;

        return Padding(
          padding: const EdgeInsets.only(left: 2, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: accent && t > 0.5 ? 11 : 9,
                  height: accent && t > 0.5 ? 11 : 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: running
                          ? scheme.primary.withValues(alpha: 0.35 + 0.4 * t)
                          : scheme.outline,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$beatLabel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: accent && t > 0.4
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: running
                      ? Color.lerp(
                          scheme.onSurface.withValues(alpha: 0.72),
                          scheme.primary,
                          accent ? t : t * 0.4,
                        )
                      : scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
