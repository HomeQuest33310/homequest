import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chronicle.dart';
import '../domain/kingdom_legend_entry.dart';
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

  @override
  Future<List<KingdomLegendEntry>> getKingdomLegend(String familyId) async {
    final data = await _client.rpc(
      'list_kingdom_legend',
      params: {
        'p_family_id': familyId,
        'p_limit': 1000,
      },
    );

    return (data as List)
        .map(
          (row) => KingdomLegendEntry.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
