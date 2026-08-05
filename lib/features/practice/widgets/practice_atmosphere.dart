import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

/// Practice-page atmosphere keyed by catalog genre / song id.
enum PracticeAtmosphereKind { night, mist, warm, rain, defaultCream }

abstract final class PracticeAtmosphereResolver {
  static PracticeAtmosphereKind resolve({
    required String genre,
    required String songId,
  }) {
    final g = genre.toLowerCase();
    final id = songId.toLowerCase();
    if (id.contains('wet_hands') ||
        id.contains('sweden') ||
        id.contains('subwoofer') ||
        id.contains('c418')) {
      return PracticeAtmosphereKind.mist;
    }
    if (id.contains('moonlight') || g.contains('classical')) {
      return PracticeAtmosphereKind.night;
    }
    if (g.contains('anime') || g.contains('pop')) {
      return PracticeAtmosphereKind.warm;
    }
    if (g.contains('game')) {
      return PracticeAtmosphereKind.rain;
    }
    return PracticeAtmosphereKind.defaultCream;
  }

  static List<Color> gradientColors(PracticeAtmosphereKind kind) {
    return switch (kind) {
      PracticeAtmosphereKind.night => const [
          Color(0xFF1A1F2E),
          Color(0xFF2A3348),
          Color(0xFF1E2433),
        ],
      PracticeAtmosphereKind.mist => const [
          Color(0xFF2C3538),
          Color(0xFF3A4548),
          Color(0xFF252B2E),
        ],
      PracticeAtmosphereKind.warm => const [
          Color(0xFF3A2A22),
          Color(0xFF4A3528),
          Color(0xFF2E221C),
        ],
      PracticeAtmosphereKind.rain => const [
          Color(0xFF1E2830),
          Color(0xFF2A3840),
          Color(0xFF182028),
        ],
      PracticeAtmosphereKind.defaultCream => [
          AppColors.background,
          AppColors.surfaceAlt,
          AppColors.background,
        ],
    };
  }

  static bool isDark(PracticeAtmosphereKind kind) =>
      kind != PracticeAtmosphereKind.defaultCream;
}

/// Soft gradient + light particles behind the practice stage.
class PracticeAtmosphereLayer extends StatefulWidget {
  const PracticeAtmosphereLayer({
    super.key,
    required this.kind,
    required this.child,
    this.enabled = true,
  });

  final PracticeAtmosphereKind kind;
  final Widget child;
  final bool enabled;

  @override
  State<PracticeAtmosphereLayer> createState() =>
      _PracticeAtmosphereLayerState();
}

class _PracticeAtmosphereLayerState extends State<PracticeAtmosphereLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final colors = PracticeAtmosphereResolver.gradientColors(widget.kind);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: CustomPaint(
            painter: _AtmospherePainter(
              kind: widget.kind,
              t: _ctrl.value,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({required this.kind, required this.t});

  final PracticeAtmosphereKind kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (kind == PracticeAtmosphereKind.defaultCream) return;
    final rng = math.Random(42);
    final n = kind == PracticeAtmosphereKind.rain ? 36 : 22;
    for (var i = 0; i < n; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final drift = (t + i * 0.03) % 1.0;
      if (kind == PracticeAtmosphereKind.rain) {
        final y = (baseY + drift * size.height * 0.4) % size.height;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 1.2, y + 10),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08)
            ..strokeWidth = 1.1,
        );
      } else {
        final y = baseY + math.sin((t + i) * math.pi * 2) * 8;
        final r = 1.2 + rng.nextDouble() * 2.2;
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.07 + rng.nextDouble() * 0.06),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.kind != kind;
}
