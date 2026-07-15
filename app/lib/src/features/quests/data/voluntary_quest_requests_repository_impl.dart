import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/quest_suggestion.dart';
import '../domain/voluntary_quest_request.dart';
import 'voluntary_quest_requests_repository.dart';

class SupabaseVoluntaryQuestRequestsRepository
    implements VoluntaryQuestRequestsRepository {
  SupabaseVoluntaryQuestRequestsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<VoluntaryQuestRequest>> listForKingdom(String kingdomId) async {
    final data = await _client
        .from('voluntary_quest_requests')
        .select()
        .eq('kingdom_id', kingdomId)
        .order('created_at', ascending: false);

    return data.map((row) => VoluntaryQuestRequest.fromMap(row)).toList();
  }

  @override
  Future<void> submit({
    required String kingdomId,
    required String domainId,
    required QuestSuggestion suggestion,
    required bool alreadyCompleted,
    String? note,
  }) async {
    final skillPoints = skillPointsForDifficulty(suggestion.difficulty);
    final skillRewards = <Map<String, dynamic>>[
      for (var index = 0; index < suggestion.skills.length; index++)
        {
          'skill_id': suggestion.skills[index].id,
          'xp_reward': skillPoints[index],
        },
    ];

    await _client.rpc(
      'submit_voluntary_quest_request',
      params: {
        'p_kingdom_id': kingdomId,
        'p_domain_id': domainId,
        'p_catalog_id': suggestion.id,
        'p_title': suggestion.heroicTitle,
        'p_real_task': suggestion.realTask,
        'p_description': null,
        'p_emoji': suggestion.emoji,
        'p_element': suggestion.element,
        'p_difficulty': suggestion.difficulty,
        'p_region_key': suggestion.locationKey,
        'p_xp_reward': suggestion.xpReward,
        'p_gold_reward': suggestion.goldReward,
        'p_boss_damage': suggestion.bossDamage,
        'p_skill_rewards': skillRewards,
        'p_already_completed': alreadyCompleted,
        'p_requester_note': note,
      },
    );
  }

  @override
  Future<void> review({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    await _client.rpc(
      'review_voluntary_quest_request',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_review_note': note,
      },
    );
  }
}
