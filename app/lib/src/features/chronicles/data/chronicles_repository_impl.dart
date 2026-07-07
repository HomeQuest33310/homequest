import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chronicle.dart';
import 'chronicles_repository.dart';

class SupabaseChroniclesRepository implements ChroniclesRepository {
  SupabaseChroniclesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Chronicle>> getRecentChronicles(String familyId) async {
    final data = await _client
        .from('chronicles')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(10);

    return data.map((row) => Chronicle.fromMap(row)).toList();
  }
}
