import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../data/boss_repository.dart';
import '../data/boss_repository_impl.dart';
import '../domain/boss.dart';

final bossRepositoryProvider = Provider<BossRepository>((ref) {
  return SupabaseBossRepository(ref.watch(supabaseProvider));
});

final currentFamilyBossesProvider = FutureProvider<List<Boss>>((ref) async {
  final kingdom = await ref.watch(currentKingdomProvider.future);
  if (kingdom == null) return const [];
  return ref.watch(bossRepositoryProvider).listBosses(kingdom.id);
});

final familyBossesRealtimeProvider = Provider.autoDispose<void>((ref) {
  final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
  if (kingdom == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client
      .channel('kingdom-bosses:${kingdom.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bosses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'kingdom_id',
          value: kingdom.id,
        ),
        callback: (_) {
          ref.invalidate(currentFamilyBossesProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

final bossControllerProvider =
    StateNotifierProvider<BossController, AsyncValue<void>>((ref) {
  return BossController(ref);
});

class BossController extends StateNotifier<AsyncValue<void>> {
  BossController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> createBoss({
    required String name,
    required String emoji,
    required String element,
    required String domainLabel,
    required String description,
    required int maxHp,
    required int difficulty,
    required int requiredLevel,
    required int xpReward,
    required String specialItem,
    required List<BossSkillReward> skillRewards,
    required bool replaceActive,
  }) async {
    final family = await _ref.read(currentFamilyProvider.future);
    final kingdom = await _ref.read(currentKingdomProvider.future);
    if (family == null || kingdom == null) return false;
    state = const AsyncLoading();
    try {
      await _ref.read(bossRepositoryProvider).createBoss(
            familyId: family.id,
            kingdomId: kingdom.id,
            name: name,
            emoji: emoji,
            element: element,
            domainLabel: domainLabel,
            description: description,
            maxHp: maxHp,
            difficulty: difficulty,
            requiredLevel: requiredLevel,
            xpReward: xpReward,
            specialItem: specialItem,
            skillRewards: skillRewards,
            replaceActive: replaceActive,
          );
      _ref.invalidate(currentFamilyBossesProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> retireBoss(String bossId) async {
    state = const AsyncLoading();
    try {
      await _ref.read(bossRepositoryProvider).retireBoss(bossId);
      _ref.invalidate(currentFamilyBossesProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
