import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Practice-page-only skin. FX off → standard [AppColors]; FX on → midnight stage.
///
/// Staff Verovio paper stays cream (`#FFFBF5`) — never themed here.
/// Left/right hand identity colors stay [AppColors.leftHand] / [rightHand].
class PracticeStageTheme {
  const PracticeStageTheme({
    required this.pageBg,
    required this.panelBg,
    required this.panelAlt,
    required this.panelBorder,
    required this.accent,
    required this.accentSoft,
    required this.waterfallTop,
    required this.waterfallMid,
    required this.waterfallNear,
    required this.waterfallHitGlow,
    required this.auroraWarm,
    required this.auroraCool,
  });

  final Color pageBg;
  final Color panelBg;
  /// Chips / unselected segment wells (must read vs [panelBg]).
  final Color panelAlt;
  final Color panelBorder;
  final Color accent;
  final Color accentSoft;
  final Color waterfallTop;
  final Color waterfallMid;
  final Color waterfallNear;
  final Color waterfallHitGlow;
  final Color auroraWarm;
  final Color auroraCool;

  /// Everyday practice chrome (matches global AppColors).
  static const standard = PracticeStageTheme(
    pageBg: AppColors.background,
    panelBg: AppColors.surface,
    panelAlt: AppColors.surfaceAlt,
    panelBorder: AppColors.borderSubtle,
    accent: AppColors.accent,
    accentSoft: AppColors.accentSoft,
    waterfallTop: Color(0xFF0B1220),
    waterfallMid: AppColors.surface,
    waterfallNear: Color(0x24E8A849),
    waterfallHitGlow: Color(0x47E8A849),
    auroraWarm: AppColors.accent,
    auroraCool: AppColors.rightHand,
  );

  /// 「午夜舞台」— deliberately far from [standard] charcoal so FX-on reads.
  /// Cool steel shell + cyan edge + bright key-light gold.
  static const midnight = PracticeStageTheme(
    pageBg: Color(0xFF020B18),
    panelBg: Color(0xFF0E2438),
    panelAlt: Color(0xFF16344C),
    panelBorder: Color(0xFF3D7A9A),
    accent: Color(0xFFFFD078),
    accentSoft: Color(0x66FFD078),
    waterfallTop: Color(0xFF01060F),
    waterfallMid: Color(0xFF0A2038),
    waterfallNear: Color(0x55FFD078),
    waterfallHitGlow: Color(0x77FFD078),
    auroraWarm: Color(0xFFFFD078),
    auroraCool: Color(0xFF4AE0F2),
  );

  static PracticeStageTheme of({required bool visualFxEnabled}) =>
      visualFxEnabled ? midnight : standard;

  /// Push stage colors into Material 3 slots SegmentedButton / chips actually use.
  ThemeData applyTo(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: accent,
      onPrimary: const Color(0xFF101820),
      primaryContainer: accentSoft,
      onPrimaryContainer: accent,
      secondary: auroraCool,
      onSecondary: const Color(0xFF041018),
      secondaryContainer: accentSoft,
      onSecondaryContainer: accent,
      surface: panelBg,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: panelAlt,
      outline: panelBorder,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBg,
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        thumbColor: accent,
        overlayColor: accentSoft,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentSoft;
            return panelAlt;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return AppColors.textSecondary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(color: accent.withValues(alpha: 0.55));
            }
            return BorderSide(color: panelBorder.withValues(alpha: 0.85));
          }),
        ),
      ),
    );
  }
}
