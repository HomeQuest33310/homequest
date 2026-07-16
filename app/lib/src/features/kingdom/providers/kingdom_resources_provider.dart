import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../domain/kingdom_resources.dart';

final currentKingdomResourcesProvider =
    FutureProvider<KingdomResources>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return KingdomResources.empty;

  final client = ref.watch(supabaseProvider);
  final results = await Future.wait<dynamic>([
    client
        .from('kingdom_resources')
        .select('wood, stone, provisions, crystals')
        .eq('family_id', family.id)
        .maybeSingle(),
    _loadBossItems(client, family.id),
  ]);
  final data = results[0];

  return KingdomResources.fromMap({
    if (data != null) ...Map<String, dynamic>.from(data as Map),
    'boss_items': results[1],
  });
});

Future<List<dynamic>> _loadBossItems(
  SupabaseClient client,
  String familyId,
) async {
  try {
    return await client
        .from('kingdom_boss_items')
        .select('item_key, name, emoji, tier, quantity')
        .eq('family_id', familyId)
        .gt('quantity', 0)
        .order('tier')
        .order('name');
  } on PostgrestException catch (error) {
    if (_isMissingPhase9Object(error)) return const [];
    rethrow;
  }
}

bool _isMissingPhase9Object(PostgrestException error) {
  return error.code == 'PGRST202' ||
      error.code == 'PGRST205' ||
      error.code == '42P01';
}

final kingdomResourcesRealtimeProvider = Provider.autoDispose<void>((ref) {
  final family = ref.watch(currentFamilyProvider).valueOrNull;
  if (family == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client
      .channel('kingdom-resources:${family.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'kingdom_resources',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: family.id,
        ),
        callback: (_) {
          ref.invalidate(currentKingdomResourcesProvider);
        },
      )
      .subscribe();

  final bossItemsChannel = client
      .channel('kingdom-boss-items:${family.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'kingdom_boss_items',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: family.id,
        ),
        callback: (_) {
          ref.invalidate(currentKingdomResourcesProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    client.removeChannel(bossItemsChannel);
  });
});
