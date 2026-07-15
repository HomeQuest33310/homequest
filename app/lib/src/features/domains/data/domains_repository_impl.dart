import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/domain.dart';
import 'domains_repository.dart';

class SupabaseDomainsRepository implements DomainsRepository {
  SupabaseDomainsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Domain>> getDomains(String kingdomId) async {
    final data = await _client
        .from('domains')
        .select()
        .eq('kingdom_id', kingdomId)
        .order('is_primary', ascending: false)
        .order('created_at');

    return data.map((row) => Domain.fromMap(row)).toList();
  }
}
