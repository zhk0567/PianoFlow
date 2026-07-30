import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0B0E13);
  static const surface = Color(0xFF141920);
  static const surfaceAlt = Color(0xFF1A212C);
  static const border = Color(0xFF2A3342);
  static const borderSubtle = Color(0xFF222A36);
  static const accent = Color(0xFFE8A849);
  static const accentSoft = Color(0x33E8A849);
  static const textPrimary = Color(0xFFF5F2EB);
  static const textSecondary = Color(0xFF9AA3B2);
  static const textMuted = Color(0xFF6E7686);
  static const success = Color(0xFF5CBF8A);
  static const danger = Color(0xFFE26A6A);
  /// Cool teal — right-hand highlights (keyboard + falling notes).
  static const rightHand = Color(0xFF4EB6C8);
  /// Warm peach-amber — left-hand highlights (near [accent], not identical).
  static const leftHand = Color(0xFFF2A06D);
  static const pianoWhite = Color(0xFFF7F3EA);
  static const pianoBlack = Color(0xFF1A1A1A);

  static const heroDeep = Color(0xFF080C14);
  static const heroGlow = Color(0x44E8A849);
}

class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppLayout {
  static const homeMaxWidth = 920.0;
  static const railWidth = 88.0;
}

class AppTheme {
  static const _cjkFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans SC',
  ];

  /// Latin brand display (e.g. PianoFlow).
  static TextStyle display({
    double fontSize = 40,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double height = 1.05,
    double letterSpacing = -0.8,
  }) {
    return GoogleFonts.syne(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: _cjkFallback);
  }

  /// UI / Chinese body — Noto Sans SC keeps CJK stroke weight even.
  /// DM Sans has almost no CJK; mixed system fallbacks caused uneven glyphs.
  static TextStyle body({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double height = 1.45,
  }) {
    return GoogleFonts.notoSansSc(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static LinearGradient get heroGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.heroDeep,
          AppColors.background,
          Color(0xFF121018),
        ],
        stops: [0.0, 0.55, 1.0],
      );

  static ThemeData dark() {
    final bodyBase =
        GoogleFonts.notoSansScTextTheme(ThemeData.dark().textTheme);
    final textTheme = bodyBase.copyWith(
      displayLarge: GoogleFonts.syne(textStyle: bodyBase.displayLarge),
      displayMedium: GoogleFonts.syne(textStyle: bodyBase.displayMedium),
      displaySmall: GoogleFonts.syne(textStyle: bodyBase.displaySmall),
      headlineLarge: GoogleFonts.syne(textStyle: bodyBase.headlineLarge),
      headlineMedium: GoogleFonts.syne(textStyle: bodyBase.headlineMedium),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.rightHand,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansSc(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        hintStyle: GoogleFonts.notoSansSc(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: GoogleFonts.notoSansSc(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.notoSansSc(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accent : AppColors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        selectedIconTheme: const IconThemeData(color: AppColors.accent),
        unselectedIconTheme:
            const IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: GoogleFonts.notoSansSc(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: GoogleFonts.notoSansSc(
          color: AppColors.textSecondary,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.accentSoft,
        labelStyle: GoogleFonts.notoSansSc(color: AppColors.textPrimary),
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.accent,
        thumbColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
      ),
      dividerColor: AppColors.border,
    );
  }
}
