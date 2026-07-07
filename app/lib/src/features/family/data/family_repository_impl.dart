import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/family.dart';
import 'family_repository.dart';

class SupabaseFamilyRepository implements FamilyRepository {
  SupabaseFamilyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Family> createFamily({
    required String familyName,
    required String kingdomName,
    required String primaryDomainName,
    required String ownerId,
  }) async {
    final data = await _client.rpc(
      'create_kingdom',
      params: {
        'p_family_name': familyName,
        'p_kingdom_name': kingdomName,
        'p_primary_domain_name': primaryDomainName,
      },
    ) as Map<String, dynamic>;

    return Family.fromMap(data);
  }

  @override
  Future<Family?> getCurrentUserFamily(String userId) async {
    final memberships = await _client
        .from('family_members')
        .select('family_id')
        .eq('user_id', userId)
        .limit(1);

    if (memberships.isEmpty) return null;

    final familyId = memberships.first['family_id'] as String;

    final data = await _client
        .from('families')
        .select()
        .eq('id', familyId)
        .maybeSingle();

    if (data == null) return null;
    return Family.fromMap(data);
  }
}
