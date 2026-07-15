import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';

class PasswordResetService {
  const PasswordResetService(this._client);

  final SupabaseClient _client;

  Future<void> requestForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _recoveryRedirectUrl(),
    );
  }

  Future<void> requestForMember({
    required String memberId,
    required String kingdomId,
  }) async {
    final response = await _client.functions.invoke(
      'request-password-reset',
      body: {
        'member_id': memberId,
        'kingdom_id': kingdomId,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error']?.toString() : null;
      throw Exception(message ?? 'La demande de réinitialisation a échoué.');
    }
  }

  String _recoveryRedirectUrl() {
    final current = Uri.base;
    final isLocalWeb = kIsWeb &&
        (current.host == 'localhost' || current.host == '127.0.0.1');
    final configured = Env.appPublicUrl.trim();
    final base = isLocalWeb || configured.isEmpty
        ? current
        : Uri.parse(configured);
    final normalized =
        base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');

    return normalized.replace(
      queryParameters: const {'password-recovery': '1'},
      fragment: '',
    ).toString();
  }
}
