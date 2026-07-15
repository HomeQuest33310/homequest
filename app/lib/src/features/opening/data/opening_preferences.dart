import 'package:shared_preferences/shared_preferences.dart';

class OpeningPreferences {
  const OpeningPreferences._();

  static const _firstAwakeningKey = 'opening.first_awakening.v1';
  static const _soundEnabledKey = 'opening.sound_enabled';

  static Future<bool> shouldShowFirstAwakening() async {
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(_firstAwakeningKey) ?? false);
  }

  static Future<void> markFirstAwakeningSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_firstAwakeningKey, true);
  }

  static Future<bool> shouldShowKingdomArrival(String invitationToken) async {
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(_kingdomKey(invitationToken)) ?? false);
  }

  static Future<void> markKingdomArrivalSeen(String invitationToken) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_kingdomKey(invitationToken), true);
  }

  static Future<bool> isSoundEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_soundEnabledKey) ?? true;
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_soundEnabledKey, enabled);
  }

  static String _kingdomKey(String invitationToken) =>
      'opening.kingdom_arrival.$invitationToken.v1';
}
