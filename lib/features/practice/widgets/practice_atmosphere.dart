import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

enum PracticeAtmosphereKind { night, mist, warm, rain, defaultDark }

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
    if (g.contains('game')) return PracticeAtmosphereKind.rain;
    return PracticeAtmosphereKind.defaultDark;
  }

  static List<Color> gradientColors(PracticeAtmosphereKind kind) {
    return switch (kind) {
      PracticeAtmosphereKind.night => const [
          Color(0xFF1A1F2E),
          Color(0xFF242B3A),
          Color(0xFF1E2433),
        ],
      PracticeAtmosphereKind.mist => const [
          Color(0xFF2C3538),
          Color(0xFF343C3F),
          Color(0xFF252B2E),
        ],
      PracticeAtmosphereKind.warm => const [
          Color(0xFF322722),
          Color(0xFF3A2E26),
          Color(0xFF2E221C),
        ],
      PracticeAtmosphereKind.rain => const [
          Color(0xFF1E2830),
          Color(0xFF253038),
          Color(0xFF182028),
        ],
      PracticeAtmosphereKind.defaultDark => [
          AppColors.background,
          AppColors.surfaceAlt,
          AppColors.background,
        ],
    };
  }
}

/// Soft static backdrop tint — no drifting particles (keeps focus on notes).
@Deprecated('练习页已卸载；教学主路径不再挂载氛围层')
class PracticeAtmosphereLayer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final colors = PracticeAtmosphereResolver.gradientColors(kind);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}
