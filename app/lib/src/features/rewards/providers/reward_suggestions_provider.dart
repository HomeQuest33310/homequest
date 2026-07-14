import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../boss/providers/boss_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../profile/providers/rpg_profile_provider.dart';
import '../data/reward_suggestions_repository.dart';
import '../data/reward_suggestions_repository_impl.dart';
import '../domain/reward_suggestion.dart';

final rewardSuggestionsRepositoryProvider =
    Provider<RewardSuggestionsRepository>((ref) {
  return SupabaseRewardSuggestionsRepository(ref.watch(supabaseProvider));
});

final currentRewardSuggestionsProvider =
    FutureProvider<List<RewardSuggestion>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];
  return ref.watch(rewardSuggestionsRepositoryProvider).listSuggestions(
        family.id,
      );
});

final rewardSuggestionsControllerProvider =
    StateNotifierProvider<RewardSuggestionsController, AsyncValue<void>>((ref) {
  return RewardSuggestionsController(ref);
});

class RewardSuggestionsController extends StateNotifier<AsyncValue<void>> {
  RewardSuggestionsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> propose({
    required String title,
    required String description,
    required int questCount,
  }) async {
    final family = await _ref.read(currentFamilyProvider.future);
    final profile = await _ref.read(currentRpgProfileProvider.future);
    if (family == null) return false;

    state = const AsyncLoading();
    try {
      await _ref.read(rewardSuggestionsRepositoryProvider).propose(
            familyId: family.id,
            memberId: profile.memberId,
            title: title,
            description: description,
            questCount: questCount,
          );
      _ref.invalidate(currentRewardSuggestionsProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> review({
    required String suggestionId,
    required String status,
    required String title,
    required String description,
    required int? questCount,
    required Map<String, dynamic>? boss,
    required bool replaceActiveBoss,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref.read(rewardSuggestionsRepositoryProvider).review(
            suggestionId: suggestionId,
            status: status,
            title: title,
            description: description,
            questCount: questCount,
            boss: boss,
            replaceActiveBoss: replaceActiveBoss,
          );
      _ref.invalidate(currentRewardSuggestionsProvider);
      _ref.invalidate(currentFamilyBossesProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
