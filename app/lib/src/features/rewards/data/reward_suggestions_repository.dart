import '../domain/reward_suggestion.dart';

abstract class RewardSuggestionsRepository {
  Future<List<RewardSuggestion>> listSuggestions(String familyId);

  Future<void> propose({
    required String familyId,
    required String memberId,
    required String title,
    required String description,
    required int questCount,
  });

  Future<void> review({
    required String suggestionId,
    required String status,
    required String title,
    required String description,
    required int? questCount,
    required Map<String, dynamic>? boss,
    required bool replaceActiveBoss,
  });

  Future<void> createGuardianGoal({
    required String familyId,
    required String title,
    required String description,
    required int? questCount,
    required Map<String, dynamic>? boss,
    required bool replaceActiveBoss,
  });

  Future<void> deliverCollectiveReward(String suggestionId);

  Future<void> updateCollectiveReward({
    required String suggestionId,
    required String title,
    required String description,
    required int? questCount,
  });

  Future<void> archiveCollectiveReward(String suggestionId);

  Future<void> reorderCollectiveRewards({
    required String familyId,
    required List<String> rewardIds,
  });
}
