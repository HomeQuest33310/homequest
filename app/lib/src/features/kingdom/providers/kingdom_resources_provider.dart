import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../domain/kingdom_resources.dart';

final currentKingdomResourcesProvider =
    FutureProvider<KingdomResources>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return KingdomResources.empty;

  final data = await ref
      .watch(supabaseProvider)
      .from('kingdom_resources')
      .select('wood, stone, provisions, crystals')
      .eq('family_id', family.id)
      .maybeSingle();

  return data == null
      ? KingdomResources.empty
      : KingdomResources.fromMap(Map<String, dynamic>.from(data));
});

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

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
