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

    final family = await _client
        .from('families')
        .insert({
          'name': familyName,
          'kingdom_name': kingdomName,
          'owner_id': user.id,
        })
        .select('id')
        .single();

    await _client.from('family_members').insert({
      'family_id': family['id'],
      'user_id': user.id,
      'role': 'guardian',
    });
  }
}
