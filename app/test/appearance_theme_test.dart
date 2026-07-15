import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/core/theme/app_appearance.dart';
import 'package:homequestoria/src/core/theme/app_theme.dart';

void main() {
  test('le thème Prologue conserve une ambiance sombre', () {
    final theme = AppTheme.build(
      const AppAppearance(style: HomeQuestThemeStyle.prologue),
    );

    expect(theme.brightness, Brightness.dark);
  });

  test('la Vision Reptilienne adapte la palette sélectionnée', () {
    final original = AppTheme.build(
      const AppAppearance(style: HomeQuestThemeStyle.green),
    );
    final adjusted = AppTheme.build(
      const AppAppearance(
        style: HomeQuestThemeStyle.green,
        reptilianLevels: {HomeQuestThemeStyle.green: 1},
      ),
    );

    expect(adjusted.colorScheme.primary, isNot(original.colorScheme.primary));
    expect(adjusted.dividerColor, isNot(original.dividerColor));
  });
}
