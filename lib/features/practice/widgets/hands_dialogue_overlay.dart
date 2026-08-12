import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../keyboard_geometry.dart';

@Deprecated('练习页已卸载；双手弧不再实时绘制')
class HandsDialogueOverlay extends StatefulWidget {
  const HandsDialogueOverlay({
    super.key,
    required this.geometry,
    required this.nonce,
    required this.leftMidi,
    required this.rightMidi,
    this.enabled = true,
  });

  final KeyboardGeometry geometry;
  final int nonce;
  final int? leftMidi;
  final int? rightMidi;
  final bool enabled;

  @override
  State<HandsDialogueOverlay> createState() => _HandsDialogueOverlayState();
}

class _HandsDialogueOverlayState extends State<HandsDialogueOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _shown = 0;
  int? _l;
  int? _r;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void didUpdateWidget(covariant HandsDialogueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) return;
    if (widget.nonce != _shown &&
        widget.leftMidi != null &&
        widget.rightMidi != null) {
      _shown = widget.nonce;
      _l = widget.leftMidi;
      _r = widget.rightMidi;
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
    if (!widget.enabled) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (_ctrl.value <= 0 || _l == null || _r == null) {
          return const SizedBox.shrink();
        }
        final lx = widget.geometry.midiToCenterX(_l!);
        final rx = widget.geometry.midiToCenterX(_r!);
        if (lx == null || rx == null) return const SizedBox.shrink();
        return CustomPaint(
          painter: _ArcPainter(leftX: lx, rightX: rx, t: _ctrl.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.leftX, required this.rightX, required this.t});

  final double leftX;
  final double rightX;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1.0 - t) * 0.42;
    final midY = size.height * 0.38;
    final rise = 10.0 * math.sin(t * math.pi);
    final path = Path()
      ..moveTo(leftX, midY)
      ..quadraticBezierTo(
        (leftX + rightX) / 2,
        midY - 16 - rise,
        rightX,
        midY,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.leftX != leftX ||
      oldDelegate.rightX != rightX;
}
