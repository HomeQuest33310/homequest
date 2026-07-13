import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mission_assignment.dart';
import '../domain/pending_completion.dart';
import 'completions_repository.dart';

class SupabaseCompletionsRepository implements CompletionsRepository {
  const SupabaseCompletionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MissionAssignment>> listMyMissions(String familyId) async {
    final data = await _client.rpc(
      'list_my_missions',
      params: {'p_family_id': familyId},
    );
    return (data as List)
        .map((item) => MissionAssignment.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  @override
  Future<List<PendingCompletion>> listPending(String familyId) async {
    final data = await _client.rpc(
      'list_pending_quest_completions',
      params: {'p_family_id': familyId},
    );
    return (data as List)
        .map((item) => PendingCompletion.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  @override
  Future<CompletionReward?> submit({
    required String questId,
    String? note,
  }) async {
    final data = Map<String, dynamic>.from(await _client.rpc(
      'submit_quest_completion',
      params: {
        'p_quest_id': questId,
        'p_note': note,
        'p_photo_url': null,
      },
    ) as Map);
    final reward = data['reward'];
    return reward == null
        ? null
        : CompletionReward.fromMap(
            Map<String, dynamic>.from(reward as Map),
          );
  }

  @override
  Future<CompletionReward> approve(String completionId) async {
    final data = await _client.rpc(
      'review_quest_completion',
      params: {
        'p_completion_id': completionId,
        'p_approve': true,
        'p_rejection_reason': null,
      },
    );
    return CompletionReward.fromMap(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> reject({
    required String completionId,
    required String reason,
  }) async {
    await _client.rpc(
      'review_quest_completion',
      params: {
        'p_completion_id': completionId,
        'p_approve': false,
        'p_rejection_reason': reason,
      },
    );
  }
}
