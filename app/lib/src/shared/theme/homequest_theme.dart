import 'package:flutter/material.dart';

class HomeQuestTheme {
  const HomeQuestTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
