import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/boss.dart';
import 'boss_repository.dart';

class SupabaseBossRepository implements BossRepository {
  SupabaseBossRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Boss>> listBosses(String kingdomId) async {
    final data = await _client.rpc(
      'list_kingdom_bosses',
      params: {'p_kingdom_id': kingdomId},
    );
    final bossRows = (data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (bossRows.isEmpty) return const [];

    final participantRows = await _client.from('boss_reward_events').select('''
      boss_id,
      boss:bosses!boss_reward_events_boss_id_fkey!inner(kingdom_id),
      member:family_members!boss_reward_events_member_id_fkey(
        profile:profiles!family_members_user_id_fkey(display_name)
      )
    ''').eq('boss.kingdom_id', kingdomId);

    final participantsByBoss = <String, Set<String>>{};
    for (final item in participantRows) {
      final row = Map<String, dynamic>.from(item);
      final member = row['member'];
      if (member is! Map) continue;
      final profile = member['profile'];
      if (profile is! Map) continue;
      final displayName = (profile['display_name'] as String?)?.trim();
      if (displayName == null || displayName.isEmpty) continue;
      participantsByBoss
          .putIfAbsent(row['boss_id'] as String, () => <String>{})
          .add(displayName);
    }

    return bossRows.map((row) {
      final names = participantsByBoss[row['id']]?.toList() ?? <String>[];
      names.sort();
      return Boss.fromMap({...row, 'participant_names': names});
    }).toList();
  }

  @override
  Future<Boss> createBoss({
    required String familyId,
    required String kingdomId,
    required String name,
    required String emoji,
    required String element,
    required String domainLabel,
    required String description,
    required int maxHp,
    required int difficulty,
    required int requiredLevel,
    required int xpReward,
    required String specialItem,
    required List<BossSkillReward> skillRewards,
    required bool replaceActive,
  }) async {
    final data = await _client.rpc(
      'create_kingdom_boss',
      params: {
        'p_family_id': familyId,
        'p_kingdom_id': kingdomId,
        'p_name': name,
        'p_emoji': emoji,
        'p_element': element,
        'p_domain_label': domainLabel,
        'p_description': description,
        'p_max_hp': maxHp,
        'p_difficulty': difficulty,
        'p_required_level': requiredLevel,
        'p_xp_reward': xpReward,
        'p_special_item': specialItem,
        'p_skill_rewards':
            skillRewards.map((reward) => reward.toRpcMap()).toList(),
        'p_replace_active': replaceActive,
      },
    );
    return Boss.fromMap(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> retireBoss(String bossId) async {
    await _client.rpc(
      'retire_family_boss',
      params: {'p_boss_id': bossId},
    );
  }
}
