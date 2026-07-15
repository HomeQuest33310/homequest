import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/quest.dart';
import 'quests_repository.dart';

class SupabaseQuestsRepository implements QuestsRepository {
  SupabaseQuestsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Quest>> listQuests(String kingdomId) async {
    final data = await _client.rpc(
      'list_available_kingdom_quests',
      params: {'p_kingdom_id': kingdomId},
    );

    return (data as List)
        .map(
          (item) => Quest.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  @override
  Future<Quest> createQuest({
    required String familyId,
    required String domainId,
    required String title,
    required String realTask,
    String? description,
    required int xpReward,
    required int goldReward,
    required int bossDamage,
    required String frequency,
    required String emoji,
    required String element,
    required int difficulty,
    required String regionKey,
    required List<QuestSkillReward> skillRewards,
  }) async {
    final data = await _client.rpc(
      'create_quest',
      params: {
        'p_family_id': familyId,
        'p_domain_id': domainId,
        'p_title': title,
        'p_real_task': realTask,
        'p_description': description,
        'p_xp_reward': xpReward,
        'p_gold_reward': goldReward,
        'p_boss_damage': bossDamage,
        'p_frequency': frequency,
        'p_emoji': emoji,
        'p_element': element,
        'p_difficulty': difficulty,
        'p_region_key': regionKey,
        'p_skill_rewards':
            skillRewards.map((reward) => reward.toRpcMap()).toList(),
      },
    );

    return Quest.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<Quest> updateQuest({
    required String questId,
    required String title,
    required String realTask,
    String? description,
    String? domainId,
    required int xpReward,
    required int goldReward,
    required int bossDamage,
    required String frequency,
    required bool requiresApproval,
    required String emoji,
    required String element,
    required int difficulty,
    required String regionKey,
    required List<QuestSkillReward> skillRewards,
  }) async {
    final data = await _client.rpc(
      'update_kingdom_quest',
      params: {
        'p_quest_id': questId,
        'p_title': title,
        'p_real_task': realTask,
        'p_description': description,
        'p_domain_id': domainId,
        'p_xp_reward': xpReward,
        'p_gold_reward': goldReward,
        'p_boss_damage': bossDamage,
        'p_frequency': frequency,
        'p_requires_approval': requiresApproval,
        'p_emoji': emoji,
        'p_element': element,
        'p_difficulty': difficulty,
        'p_region_key': regionKey,
        'p_skill_rewards':
            skillRewards.map((reward) => reward.toRpcMap()).toList(),
      },
    );

    return Quest.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<Quest> archiveQuest(String questId) async {
    final data = await _client.rpc(
      'archive_quest',
      params: {
        'quest_id': questId,
      },
    );

    return Quest.fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> assignQuest({
    required String questId,
    required String memberId,
  }) async {
    await _client.rpc(
      'assign_quest',
      params: {
        'p_quest_id': questId,
        'p_member_id': memberId,
      },
    );
  }

  @override
  Future<void> selfAssignQuest(String questId) async {
    await _client.rpc(
      'self_assign_quest',
      params: {
        'p_quest_id': questId,
      },
    );
  }
}
