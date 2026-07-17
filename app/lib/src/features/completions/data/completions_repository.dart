import '../domain/mission_assignment.dart';
import '../domain/pending_completion.dart';

abstract class CompletionsRepository {
  Future<List<MissionAssignment>> listMyMissions(String familyId);
  Future<void> leave(String questId);
  Future<List<PendingCompletion>> listPending(String familyId);
  Future<CompletionReward?> submit({
    required String questId,
    String? note,
  });
  Future<CompletionReward> approve(String completionId);
  Future<void> reject({
    required String completionId,
    required String reason,
  });
}
