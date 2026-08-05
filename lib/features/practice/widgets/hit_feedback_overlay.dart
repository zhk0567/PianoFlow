import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../practice_judge_logic.dart';

/// Brief grade flash above the hit line — event-driven, not 60 Hz.
class HitFeedbackOverlay extends StatefulWidget {
  const HitFeedbackOverlay({
    super.key,
    required this.grade,
    required this.nonce,
  });

  final HitGrade? grade;
  final int nonce;

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
      duration: const Duration(milliseconds: 420),
    );
    if (widget.grade != null && widget.nonce > 0) {
      _flash(widget.grade!);
    }
  }

  @override
  void didUpdateWidget(covariant HitFeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nonce != oldWidget.nonce && widget.grade != null) {
      _flash(widget.grade!);
    }
  }

  void _flash(HitGrade grade) {
    if (!grade.showsFeedback) {
      _shown = null;
      _ctrl.stop();
      _ctrl.value = 0;
      return;
    }
    _shown = grade;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _color(HitGrade g) => switch (g) {
        HitGrade.perfect => AppColors.success,
        HitGrade.good => AppColors.accent,
        HitGrade.miss => AppColors.accent, // unused — miss never flashes
      };

  @override
  Widget build(BuildContext context) {
    final grade = _shown;
    final label = grade?.labelZh;
    if (grade == null || label == null) return const SizedBox.expand();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          // Fade in then out.
          final opacity = t < 0.25
              ? (t / 0.25)
              : (1.0 - ((t - 0.25) / 0.75)).clamp(0.0, 1.0);
          final dy = -12.0 * t;
          return Align(
            alignment: const Alignment(0, 0.72),
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Text(
                  label,
                  style: AppTheme.body(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _color(grade),
                    height: 1.1,
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
