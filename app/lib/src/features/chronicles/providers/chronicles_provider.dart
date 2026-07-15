import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/chronicles_repository.dart';
import '../data/chronicles_repository_impl.dart';
import '../domain/chronicle.dart';
import '../domain/kingdom_legend_entry.dart';

final chroniclesRepositoryProvider = Provider<ChroniclesRepository>((ref) {
  return SupabaseChroniclesRepository(ref.watch(supabaseProvider));
});

final recentChroniclesProvider = FutureProvider<List<Chronicle>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];
  return ref.watch(chroniclesRepositoryProvider).getRecentChronicles(family.id);
});

final kingdomLegendProvider =
    FutureProvider<List<KingdomLegendEntry>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];
  return ref.watch(chroniclesRepositoryProvider).getKingdomLegend(family.id);
});

final kingdomLegendRealtimeProvider = Provider.autoDispose<void>((ref) {
  final family = ref.watch(currentFamilyProvider).valueOrNull;
  if (family == null) return;

  final client = ref.watch(supabaseProvider);
  final tables = ['family_members', 'bosses', 'reward_suggestions'];
  final channels = tables.map((table) {
    return client
        .channel('kingdom-celebrations:${family.id}:$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'family_id',
            value: family.id,
          ),
          callback: (_) {
            ref.invalidate(kingdomLegendProvider);
            ref.invalidate(recentChroniclesProvider);
          },
        )
        .subscribe();
  }).toList();

  ref.onDispose(() {
    for (final channel in channels) {
      client.removeChannel(channel);
    }
  });
});
