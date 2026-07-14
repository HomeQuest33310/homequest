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
    required int questCount,
    required String bossTheme,
  });
}
