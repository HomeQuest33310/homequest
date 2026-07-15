import 'package:shared_preferences/shared_preferences.dart';

class CelebrationPreferences {
  static const _prefix = 'seen_kingdom_celebrations_v1';

  static String _key(String userId, String familyId) =>
      '$_prefix:$userId:$familyId';

  static Future<Set<String>> seenIds({
    required String userId,
    required String familyId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_key(userId, familyId))?.toSet() ?? {};
  }

  static Future<void> markSeen({
    required String userId,
    required String familyId,
    required String eventId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(userId, familyId);
    final ids = preferences.getStringList(key)?.toList() ?? <String>[];
    ids.remove(eventId);
    ids.add(eventId);
    if (ids.length > 200) ids.removeRange(0, ids.length - 200);
    await preferences.setStringList(key, ids);
  }
}
