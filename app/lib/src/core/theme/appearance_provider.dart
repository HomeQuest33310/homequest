import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_appearance.dart';

final appearanceProvider =
    StateNotifierProvider<AppearanceController, AppAppearance>((ref) {
  return AppearanceController()..load();
});

class AppearanceController extends StateNotifier<AppAppearance> {
  AppearanceController() : super(const AppAppearance());

  static const _styleKey = 'homequest_theme_style_v1';
  static const _reptilianPrefix = 'homequest_reptilian_level_v1';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedStyle = preferences.getString(_styleKey);
    final style = HomeQuestThemeStyle.values.firstWhere(
      (candidate) => candidate.name == savedStyle,
      orElse: () => HomeQuestThemeStyle.classic,
    );
    final levels = <HomeQuestThemeStyle, double>{};
    for (final candidate in HomeQuestThemeStyle.values) {
      levels[candidate] =
          preferences.getDouble('$_reptilianPrefix:${candidate.name}') ?? 0;
    }
    state = AppAppearance(style: style, reptilianLevels: levels);
  }

  Future<void> selectStyle(HomeQuestThemeStyle style) async {
    state = state.copyWith(style: style);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_styleKey, style.name);
  }

  Future<void> setReptilianLevel(double level) async {
    final normalized = level.clamp(0.0, 1.0);
    final levels = Map<HomeQuestThemeStyle, double>.from(
      state.reptilianLevels,
    )..[state.style] = normalized;
    state = state.copyWith(reptilianLevels: levels);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(
      '$_reptilianPrefix:${state.style.name}',
      normalized,
    );
  }
}
