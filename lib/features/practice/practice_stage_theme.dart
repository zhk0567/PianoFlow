import 'package:flutter/material.dart';

import '../../shared/models/song.dart';
import '../../shared/theme/app_theme.dart';

/// Practice-page-only skin. FX off → [standard] paper. FX on → [decorated]:
/// the same warm family, a step deeper so the waterfall stays readable.
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
    required this.textPrimary,
    required this.textSecondary,
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
  final Color textPrimary;
  final Color textSecondary;

  /// Everyday practice chrome (matches global AppColors).
  static const standard = PracticeStageTheme(
    pageBg: AppColors.background,
    panelBg: AppColors.surface,
    panelAlt: AppColors.surfaceAlt,
    panelBorder: AppColors.borderSubtle,
    accent: AppColors.accent,
    accentSoft: AppColors.accentSoft,
    waterfallTop: Color(0xFFE7DDD0),
    waterfallMid: AppColors.surface,
    waterfallNear: Color(0x33C9843A),
    waterfallHitGlow: Color(0x55C9843A),
    auroraWarm: AppColors.accentWarm,
    auroraCool: AppColors.rightHand,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
  );

  /// Decorative stage — warm paper, slightly deeper than [standard].
  /// Sage accent (sliders / chips), walnut waterfall, no midnight blue or gold.
  static const decorated = PracticeStageTheme(
    pageBg: Color(0xFFE3D6C4),
    panelBg: Color(0xFFF6F0E6),
    panelAlt: Color(0xFFEADFCF),
    panelBorder: Color(0xFFDCCFBF),
    accent: AppColors.accent,
    accentSoft: AppColors.accentSoft,
    waterfallTop: Color(0xFF9C8C76),
    waterfallMid: Color(0xFFB3A28C),
    waterfallNear: Color(0x66A88458),
    waterfallHitGlow: Color(0x554A6B4C),
    auroraWarm: AppColors.accentWarm,
    auroraCool: AppColors.rightHand,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
  );

  static PracticeStageTheme of({required bool visualFxEnabled}) =>
      visualFxEnabled ? decorated : standard;

  /// Waterfall / key hand identity — **only** LH vs RH (never voice / staff / layer).
  ///
  /// [Hand.both] shares the right-hand color so both-hands mode stays two hues.
  static Color colorForHand(Hand hand) =>
      hand == Hand.left ? AppColors.leftHand : AppColors.rightHand;

  /// Wait-target emphasis without introducing a third identity hue.
  static Color waitingFillForHand(Hand hand) =>
      Color.lerp(colorForHand(hand), Colors.white, 0.28)!;

  /// Push stage colors into Material 3 slots SegmentedButton / chips actually use.
  ThemeData applyTo(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: accent,
      onPrimary: AppColors.onFill(accent),
      primaryContainer: accentSoft,
      onPrimaryContainer: accent,
      secondary: auroraCool,
      onSecondary: AppColors.onFill(auroraCool),
      secondaryContainer: accentSoft,
      onSecondaryContainer: accent,
      surface: panelBg,
      onSurface: textPrimary,
      surfaceContainerHighest: panelAlt,
      outline: panelBorder,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBg,
      iconTheme: IconThemeData(color: textPrimary),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
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
            return textSecondary;
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
