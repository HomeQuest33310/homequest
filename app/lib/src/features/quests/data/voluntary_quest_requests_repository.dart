import '../domain/quest_suggestion.dart';
import '../domain/voluntary_quest_request.dart';

abstract class VoluntaryQuestRequestsRepository {
  Future<List<VoluntaryQuestRequest>> listForKingdom(String kingdomId);

  Future<void> submit({
    required String kingdomId,
    required String domainId,
    required QuestSuggestion suggestion,
    required bool alreadyCompleted,
    String? note,
  });

  Future<void> review({
    required String requestId,
    required bool approve,
    String? note,
  });
}
