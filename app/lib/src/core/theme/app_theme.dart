import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_appearance.dart';

class AppTheme {
  static const primaryColor = Color(0xFF6366F1);
  static const secondaryColor = Color(0xFF10B981);
  static const tertiaryColor = Color(0xFFF59E0B);
  static const errorColor = Color(0xFFEF4444);
  static const warningColor = tertiaryColor;
  static const successColor = secondaryColor;
  static const black = Color(0xFF000000);
  static const gray900 = Color(0xFF111827);
  static const gray800 = Color(0xFF1F2937);
  static const gray700 = Color(0xFF374151);
  static const gray600 = Color(0xFF4B5563);
  static const gray500 = Color(0xFF6B7280);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray50 = Color(0xFFFAFAFA);
  static const white = Color(0xFFFFFFFF);
  static const spacingXs = 4.0;
  static const spacingSm = 8.0;
  static const spacingMd = 16.0;
  static const spacingLg = 24.0;
  static const spacingXl = 32.0;
  static const spacing2xl = 48.0;
  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 16.0;
  static const radius2xl = 24.0;

  static ThemeData build(
    AppAppearance appearance, {
    bool useGoogleFonts = true,
  }) {
    final palette = _ThemePalette.forStyle(
      appearance.style,
    ).withReptilianVision(appearance.reptilianLevel);
    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: palette.brightness,
      ).copyWith(
        primary: palette.primary,
        secondary: palette.secondary,
        tertiary: palette.tertiary,
        surface: palette.surface,
        error: errorColor,
      ),
    );
    final textTheme = (useGoogleFonts
            ? GoogleFonts.poppinsTextTheme(base.textTheme)
            : base.textTheme)
        .apply(
      bodyColor: palette.onSurface,
      displayColor: palette.onSurface,
    );
    final titleTextStyle = useGoogleFonts
        ? GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.onSurface,
          )
        : TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.onSurface,
          );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: titleTextStyle,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: appearance.style == HomeQuestThemeStyle.prologue ? 4 : 2,
        shadowColor: palette.primary.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.input,
        border: _inputBorder(palette.outline),
        enabledBorder: _inputBorder(palette.outline),
        focusedBorder: _inputBorder(palette.primary, width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingMd,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: palette.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: palette.outline),
        backgroundColor: palette.input,
      ),
      dividerColor: palette.outline,
    );
  }

  static ThemeData get lightTheme => build(const AppAppearance());

  static ThemeData get darkTheme => build(
        const AppAppearance(style: HomeQuestThemeStyle.dark),
      );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _ThemePalette {
  const _ThemePalette({
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.input,
    required this.onSurface,
    required this.outline,
  });

  factory _ThemePalette.forStyle(HomeQuestThemeStyle style) => switch (style) {
        HomeQuestThemeStyle.classic => const _ThemePalette(
            brightness: Brightness.light,
            primary: Color(0xFF5B5BD6),
            secondary: Color(0xFF168B68),
            tertiary: Color(0xFFB87300),
            background: Color(0xFFF7F7FC),
            surface: Colors.white,
            input: Color(0xFFF2F2F8),
            onSurface: Color(0xFF1A1B2B),
            outline: Color(0xFFC8C8D8),
          ),
        HomeQuestThemeStyle.prologue => const _ThemePalette(
            brightness: Brightness.dark,
            primary: Color(0xFFD8BD69),
            secondary: Color(0xFF9A82E2),
            tertiary: Color(0xFFE9DDAF),
            background: Color(0xFF070817),
            surface: Color(0xFF121126),
            input: Color(0xFF201D3D),
            onSurface: Color(0xFFF8F3E4),
            outline: Color(0xFF5B517B),
          ),
        HomeQuestThemeStyle.dark => const _ThemePalette(
            brightness: Brightness.dark,
            primary: Color(0xFF9F9CFF),
            secondary: Color(0xFF67DCC0),
            tertiary: Color(0xFFFFC65A),
            background: Color(0xFF0D1117),
            surface: Color(0xFF171C24),
            input: Color(0xFF222936),
            onSurface: Color(0xFFF0F3F8),
            outline: Color(0xFF495365),
          ),
        HomeQuestThemeStyle.girly => const _ThemePalette(
            brightness: Brightness.light,
            primary: Color(0xFFB93478),
            secondary: Color(0xFF8A4FB8),
            tertiary: Color(0xFFD16A45),
            background: Color(0xFFFFF5FA),
            surface: Color(0xFFFFFBFD),
            input: Color(0xFFFFEAF4),
            onSurface: Color(0xFF3B2031),
            outline: Color(0xFFD8A9C1),
          ),
        HomeQuestThemeStyle.green => const _ThemePalette(
            brightness: Brightness.light,
            primary: Color(0xFF176B4D),
            secondary: Color(0xFF497A2D),
            tertiary: Color(0xFF9A641C),
            background: Color(0xFFF1F7F0),
            surface: Color(0xFFFBFEFA),
            input: Color(0xFFE4F0E2),
            onSurface: Color(0xFF173027),
            outline: Color(0xFFA9BEA8),
          ),
      };

  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color background;
  final Color surface;
  final Color input;
  final Color onSurface;
  final Color outline;

  _ThemePalette withReptilianVision(double amount) {
    if (amount <= 0) return this;
    final dark = brightness == Brightness.dark;
    return _ThemePalette(
      brightness: brightness,
      primary: Color.lerp(primary, const Color(0xFF2D7DD2), amount)!,
      secondary: Color.lerp(secondary, const Color(0xFFE6A700), amount)!,
      tertiary: Color.lerp(tertiary, const Color(0xFF7A5CC7), amount)!,
      background: Color.lerp(
        background,
        dark ? const Color(0xFF080B10) : const Color(0xFFF8FAFC),
        amount,
      )!,
      surface: Color.lerp(
        surface,
        dark ? const Color(0xFF121821) : Colors.white,
        amount,
      )!,
      input: Color.lerp(
        input,
        dark ? const Color(0xFF1D2733) : const Color(0xFFE9EEF5),
        amount,
      )!,
      onSurface: Color.lerp(
        onSurface,
        dark ? Colors.white : const Color(0xFF101820),
        amount,
      )!,
      outline: Color.lerp(
        outline,
        dark ? const Color(0xFF8391A4) : const Color(0xFF66768A),
        amount,
      )!,
    );
  }
}
