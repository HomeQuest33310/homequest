import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/quest.dart';
import 'quests_repository.dart';

class SupabaseQuestsRepository implements QuestsRepository {
  SupabaseQuestsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Quest>> listQuests(String familyId) async {
    final data = await _client
        .from('quests')
        .select()
        .eq('family_id', familyId)
        .neq('status', 'archived')
        .order('created_at', ascending: false);

    return (data as List)
        .map((item) => Quest.fromMap(Map<String, dynamic>.from(item)))
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
  }) async {
    final data = await _client.rpc(
      'update_quest',
      params: {
        'quest_id': questId,
        'new_title': title,
        'new_real_task': realTask,
        'new_description': description,
        'new_domain_id': domainId,
        'new_xp_reward': xpReward,
        'new_gold_reward': goldReward,
        'new_boss_damage': bossDamage,
        'new_frequency': frequency,
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
}