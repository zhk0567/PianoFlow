import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../practice_judge_logic.dart';

/// Brief grade flash above the hit line — event-driven, kept quiet.
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
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant HitFeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
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
          final opacity = ((1.0 - t) * 0.88).clamp(0.0, 1.0);
          return Align(
            alignment: const Alignment(0, 0.58),
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, -8 * t),
                child: Text(
                  label,
                  style: AppTheme.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _shown == HitGrade.perfect
                        ? AppColors.success
                        : AppColors.accent,
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
