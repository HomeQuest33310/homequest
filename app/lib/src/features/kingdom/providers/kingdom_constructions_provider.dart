import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../domain/kingdom_construction.dart';
import 'kingdom_resources_provider.dart';

final currentKingdomConstructionsProvider =
    FutureProvider<List<KingdomConstruction>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];

  final client = ref.watch(supabaseProvider);
  try {
    final production = Map<String, dynamic>.from(
      await client.rpc(
        'claim_kingdom_production',
        params: {'p_family_id': family.id},
      ) as Map,
    );
    if ((production['wood'] as num? ?? 0) > 0 ||
        (production['provisions'] as num? ?? 0) > 0) {
      ref.invalidate(currentKingdomResourcesProvider);
    }

    final data = await client.rpc(
      'list_kingdom_buildings',
      params: {'p_family_id': family.id},
    );
    final constructions = (data as List)
        .map(
          (item) => KingdomConstruction.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    final upcoming = constructions
        .where((item) => item.isInProgress && item.remaining > Duration.zero)
        .map((item) => item.remaining)
        .fold<Duration?>(
          null,
          (shortest, duration) =>
              shortest == null || duration < shortest ? duration : shortest,
        );
    Timer? timer;
    if (upcoming != null) {
      timer = Timer(upcoming + const Duration(seconds: 1), ref.invalidateSelf);
    }
    ref.onDispose(() => timer?.cancel());
    return constructions;
  } on PostgrestException catch (error) {
    if (_isMissingPhase9Object(error)) return const [];
    rethrow;
  }
});

final kingdomConstructionsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final family = ref.watch(currentFamilyProvider).valueOrNull;
  if (family == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client
      .channel('kingdom-buildings:${family.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'kingdom_buildings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: family.id,
        ),
        callback: (_) {
          ref.invalidate(currentKingdomConstructionsProvider);
          ref.invalidate(currentKingdomResourcesProvider);
        },
      )
      .subscribe();

  ref.onDispose(() => client.removeChannel(channel));
});

final kingdomEconomyControllerProvider =
    StateNotifierProvider<KingdomEconomyController, AsyncValue<void>>((ref) {
  return KingdomEconomyController(ref);
});

class KingdomEconomyController extends StateNotifier<AsyncValue<void>> {
  KingdomEconomyController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> startConstruction(String buildingKey) async {
    return _run((client, familyId) async {
      await client.rpc(
        'start_kingdom_construction',
        params: {
          'p_family_id': familyId,
          'p_building_key': buildingKey,
        },
      );
    });
  }

  Future<bool> convertCrystal(String resourceKey) async {
    return _run((client, familyId) async {
      await client.rpc(
        'convert_kingdom_crystals',
        params: {
          'p_family_id': familyId,
          'p_resource_key': resourceKey,
          'p_crystals': 1,
        },
      );
    });
  }

  Future<bool> _run(
    Future<void> Function(SupabaseClient client, String familyId) action,
  ) async {
    state = const AsyncLoading();
    try {
      final family = await _ref.read(currentFamilyProvider.future);
      if (family == null) throw StateError('Aucun royaume actif.');
      await action(_ref.read(supabaseProvider), family.id);
      _ref.invalidate(currentKingdomConstructionsProvider);
      _ref.invalidate(currentKingdomResourcesProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

bool _isMissingPhase9Object(PostgrestException error) {
  return error.code == 'PGRST202' ||
      error.code == 'PGRST205' ||
      error.code == '42P01';
}
