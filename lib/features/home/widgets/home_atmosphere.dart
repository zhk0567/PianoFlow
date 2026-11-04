import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

/// Decorative piano-key / falling-note atmosphere behind the home hero.
class HomeAtmosphere extends StatelessWidget {
  const HomeAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppTheme.heroGradient),
      child: CustomPaint(
        painter: _HomeAtmospherePainter(),
        child: child,
      ),
    );
  }
}

class _HomeAtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft amber glow blob near bottom-right of hero area.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accent.withValues(alpha: 0.22),
          AppColors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.78, size.height * 0.28),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.28),
      size.width * 0.45,
      glow,
    );

    // Minimal falling bars (abstract notes).
    final barPaint = Paint()
      ..color = AppColors.rightHand.withValues(alpha: 0.12)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final leftPaint = Paint()
      ..color = AppColors.leftHand.withValues(alpha: 0.10)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    final xs = [
      size.width * 0.12,
      size.width * 0.22,
      size.width * 0.55,
      size.width * 0.68,
      size.width * 0.88,
    ];
    final tops = [40.0, 70.0, 30.0, 90.0, 55.0];
    final heights = [48.0, 72.0, 36.0, 60.0, 44.0];
    for (var i = 0; i < xs.length; i++) {
      final p = i.isEven ? barPaint : leftPaint;
      canvas.drawLine(
        Offset(xs[i], tops[i]),
        Offset(xs[i], tops[i] + heights[i]),
        p,
      );
    }

    // Thin keyboard silhouette at lower hero.
    final keyY = size.height * 0.42;
    final keyPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final keyW = size.width / 28;
    for (var i = 0; i < 28; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * keyW + 8, keyY, keyW - 2, 28),
          const Radius.circular(2),
        ),
        keyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
