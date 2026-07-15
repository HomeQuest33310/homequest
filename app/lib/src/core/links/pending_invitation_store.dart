import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pendingInvitationTokenProvider = FutureProvider<String?>((ref) {
  return PendingInvitationStore.read();
});

class PendingInvitationStore {
  const PendingInvitationStore._();

  static const _tokenKey = 'homequest_pending_invitation_token_v1';

  static Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  static Future<void> save(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, normalized);
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}
