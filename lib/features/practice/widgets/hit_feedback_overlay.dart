import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../practice_judge_logic.dart';

/// Brief grade flash above the hit line — event-driven.
///
/// When [enhanced] (视觉特效), larger type + ring so it reads as celebration.
class HitFeedbackOverlay extends StatefulWidget {
  const HitFeedbackOverlay({
    super.key,
    required this.grade,
    required this.nonce,
    this.enhanced = false,
  });

  final HitGrade? grade;
  final int nonce;
  final bool enhanced;

  @override
  State<HitFeedbackOverlay> createState() => _HitFeedbackOverlayState();
}

class _HitFeedbackOverlayState extends State<HitFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  HitGrade? _shown;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.enhanced ? 720 : 320),
    );
  }

  @override
  void didUpdateWidget(covariant HitFeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enhanced != oldWidget.enhanced) {
      _ctrl.duration =
          Duration(milliseconds: widget.enhanced ? 720 : 320);
    }
    if (widget.nonce != oldWidget.nonce &&
        widget.grade != null &&
        widget.grade!.showsFeedback) {
      _shown = widget.grade;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final label = _shown?.labelZh;
          if (label == null || _ctrl.value <= 0) {
            return const SizedBox.shrink();
          }
          final t = Curves.easeOut.transform(_ctrl.value);
          final opacity = ((1.0 - t) * 0.92).clamp(0.0, 1.0);
          final perfect = _shown == HitGrade.perfect;
          final color =
              perfect ? AppColors.success : AppColors.accent;
          final scale = widget.enhanced
              ? (1.0 + 0.18 * (1 - t))
              : 1.0;
          return Align(
            alignment: const Alignment(0, 0.48),
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, -18 * t - (widget.enhanced ? 10 : 0)),
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.enhanced)
                        Container(
                          width: perfect ? 36 : 28,
                          height: perfect ? 36 : 28,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.28),
                                color.withValues(alpha: 0.18),
                                color.withValues(alpha: 0.0),
                              ],
                            ),
                            border: Border.all(
                              color: color.withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                          ),
                        ),
                      Text(
                        label,
                        style: AppTheme.body(
                          fontSize: widget.enhanced
                              ? (perfect ? 24 : 20)
                              : 16,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
