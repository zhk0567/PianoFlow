import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  /// Echo-like paper shell: warm page, cream cards, sage accent.
  static const background = Color(0xFFEDE6D8);
  static const surface = Color(0xFFFAF6EE);
  static const surfaceAlt = Color(0xFFF5EFE6);
  static const paper = Color(0xFFFFF9F0);
  static const border = Color(0xFFD9CFC0);
  static const borderSubtle = Color(0xFFE8DFD4);
  static const accent = Color(0xFF4A6B4C);
  static const accentHover = Color(0xFF3D5A3F);
  /// Selected nav / chip wash: sage at the same lightness, blue pulled down so it stays warm paper.
  static const accentSoft = Color(0xFFDCE8C8);
  static const accentWarm = Color(0xFFA88458);
  static const accentWarmSoft = Color(0xFFF0E4D4);
  /// Ink on [accent] (sage is dark enough for white labels).
  static const onAccent = Color(0xFFFFF9F0);
  static const textPrimary = Color(0xFF1F1A16);
  static const textSecondary = Color(0xFF4A433C);
  static const textMuted = Color(0xFF6B6258);
  static const success = Color(0xFF4A7A54);
  static const danger = Color(0xFFA84F4F);
  /// Cool teal — right-hand highlights (keyboard + falling notes).
  static const rightHand = Color(0xFF3D8A9A);
  /// Warm peach — left-hand highlights.
  static const leftHand = Color(0xFFC4784A);
  static const pianoWhite = Color(0xFFFFFCF7);
  static const pianoBlack = Color(0xFF241C16);
  /// Waiting / pressed key — warm amber, readable on both white and black keys.
  static const keyWait = Color(0xFFC9843A);
  /// Light text that sits on dark covers (album art), not page ink.
  static const onCover = Color(0xFFFFF6EC);
  static const onCoverMuted = Color(0xFFE4D3C0);

  static const shadow = Color(0x141F1A16);

  /// Label color that stays readable on [fill] (sage → cream, gold → ink).
  static Color onFill(Color fill) =>
      fill.computeLuminance() > 0.45 ? textPrimary : onAccent;
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
          Color(0xFFF7F1E6),
          AppColors.background,
          Color(0xFFE4DBC9),
        ],
        stops: [0.0, 0.55, 1.0],
      );

  static ThemeData light() {
    final bodyBase =
        GoogleFonts.notoSansScTextTheme(ThemeData.light().textTheme);
    final textTheme = bodyBase.copyWith(
      displayLarge: GoogleFonts.syne(textStyle: bodyBase.displayLarge),
      displayMedium: GoogleFonts.syne(textStyle: bodyBase.displayMedium),
      displaySmall: GoogleFonts.syne(textStyle: bodyBase.displaySmall),
      headlineLarge: GoogleFonts.syne(textStyle: bodyBase.headlineLarge),
      headlineMedium: GoogleFonts.syne(textStyle: bodyBase.headlineMedium),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      colorScheme: const ColorScheme.light(
        surface: AppColors.surface,
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        primaryContainer: AppColors.accentSoft,
        onPrimaryContainer: AppColors.accent,
        secondary: AppColors.accentWarm,
        onSecondary: AppColors.onAccent,
        secondaryContainer: AppColors.accentWarmSoft,
        onSecondaryContainer: Color(0xFF5C4630),
        error: AppColors.danger,
        onError: AppColors.onAccent,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderSubtle,
        surfaceContainerHighest: AppColors.surfaceAlt,
        surfaceContainerHigh: AppColors.paper,
        surfaceContainer: AppColors.surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansSc(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.notoSansSc(
          color: AppColors.onAccent,
          fontSize: 14,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderSubtle),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.onAccent;
          return AppColors.paper;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.border;
        }),
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
          foregroundColor: AppColors.onAccent,
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
        surfaceTintColor: Colors.transparent,
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
