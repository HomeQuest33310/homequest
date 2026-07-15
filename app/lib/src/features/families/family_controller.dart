import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final familyControllerProvider = Provider<FamilyController>((ref) {
  return FamilyController(Supabase.instance.client);
});

class FamilyController {
  FamilyController(this._client);

  final SupabaseClient _client;

  Future<void> createFamily({
    required String familyName,
    required String kingdomName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Utilisateur non connecté');

    await _client.rpc(
      'create_kingdom',
      params: {
        'p_family_name': familyName,
        'p_kingdom_name': kingdomName,
        'p_primary_domain_name': 'Maison principale',
      },
    );
  }
}
