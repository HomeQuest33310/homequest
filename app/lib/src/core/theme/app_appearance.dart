import 'package:flutter/material.dart';

enum HomeQuestThemeStyle { classic, prologue, dark, girly, green }

extension HomeQuestThemeStyleDetails on HomeQuestThemeStyle {
  String get label => switch (this) {
        HomeQuestThemeStyle.classic => 'Classique',
        HomeQuestThemeStyle.prologue => 'Prologue',
        HomeQuestThemeStyle.dark => 'Sombre',
        HomeQuestThemeStyle.girly => 'Girly',
        HomeQuestThemeStyle.green => 'Green',
      };

  String get description => switch (this) {
        HomeQuestThemeStyle.classic => 'Clair, royal et équilibré',
        HomeQuestThemeStyle.prologue => 'Mystique, violet et or',
        HomeQuestThemeStyle.dark => 'Nocturne et contrasté',
        HomeQuestThemeStyle.girly => 'Rose, chaleureux et lumineux',
        HomeQuestThemeStyle.green => 'Forêt, nature et aventure',
      };

  IconData get icon => switch (this) {
        HomeQuestThemeStyle.classic => Icons.castle_outlined,
        HomeQuestThemeStyle.prologue => Icons.auto_awesome,
        HomeQuestThemeStyle.dark => Icons.nightlight_round,
        HomeQuestThemeStyle.girly => Icons.local_florist_outlined,
        HomeQuestThemeStyle.green => Icons.forest_outlined,
      };
}

class AppAppearance {
  const AppAppearance({
    this.style = HomeQuestThemeStyle.classic,
    this.reptilianLevels = const {},
  });

  final HomeQuestThemeStyle style;
  final Map<HomeQuestThemeStyle, double> reptilianLevels;

  double get reptilianLevel => reptilianLevels[style] ?? 0;

  AppAppearance copyWith({
    HomeQuestThemeStyle? style,
    Map<HomeQuestThemeStyle, double>? reptilianLevels,
  }) {
    return AppAppearance(
      style: style ?? this.style,
      reptilianLevels: reptilianLevels ?? this.reptilianLevels,
    );
  }
}
