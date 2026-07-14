import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../boss/providers/boss_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../profile/providers/rpg_profile_provider.dart';
import '../data/reward_suggestions_repository.dart';
import '../data/reward_suggestions_repository_impl.dart';
import '../domain/reward_suggestion.dart';

class RewardDecisionNotice {
  const RewardDecisionNotice({
    required this.title,
    required this.status,
  });

  final String title;
  final String status;
}

final rewardDecisionNoticeProvider =
    StateProvider<RewardDecisionNotice?>((ref) => null);

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

final rewardSuggestionsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final family = ref.watch(currentFamilyProvider).valueOrNull;
  if (family == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client
      .channel('reward-suggestions:${family.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reward_suggestions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: family.id,
        ),
        callback: (payload) {
          ref.invalidate(currentRewardSuggestionsProvider);

          if (payload.eventType != PostgresChangeEvent.update) return;

          final newStatus = payload.newRecord['status'] as String?;
          final oldStatus = payload.oldRecord['status'] as String?;
          if (newStatus == oldStatus ||
              (newStatus != 'approved' && newStatus != 'rejected')) {
            return;
          }

          final profile = ref.read(currentRpgProfileProvider).valueOrNull;
          final proposerId = payload.newRecord['proposed_by'] as String?;
          if (profile == null || profile.memberId != proposerId) return;

          final title =
              (payload.newRecord['guardian_title'] as String?)?.trim();
          final originalTitle = (payload.newRecord['title'] as String?)?.trim();
          ref.read(rewardDecisionNoticeProvider.notifier).state =
              RewardDecisionNotice(
            title: title?.isNotEmpty == true
                ? title!
                : (originalTitle?.isNotEmpty == true
                    ? originalTitle!
                    : 'Votre souhait'),
            status: newStatus!,
          );
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
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
