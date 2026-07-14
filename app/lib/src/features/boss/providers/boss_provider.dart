import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/boss_repository.dart';
import '../data/boss_repository_impl.dart';
import '../domain/boss.dart';

final bossRepositoryProvider = Provider<BossRepository>((ref) {
  return SupabaseBossRepository(ref.watch(supabaseProvider));
});

final currentFamilyBossesProvider = FutureProvider<List<Boss>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];
  return ref.watch(bossRepositoryProvider).listBosses(family.id);
});

final familyBossesRealtimeProvider = Provider.autoDispose<void>((ref) {
  final family = ref.watch(currentFamilyProvider).valueOrNull;
  if (family == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client
      .channel('family-bosses:${family.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bosses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: family.id,
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
    if (family == null) return false;
    state = const AsyncLoading();
    try {
      await _ref.read(bossRepositoryProvider).createBoss(
            familyId: family.id,
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
