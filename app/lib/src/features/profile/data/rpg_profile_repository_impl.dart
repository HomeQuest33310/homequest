import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/rpg_profile.dart';
import 'rpg_profile_repository.dart';

class SupabaseRpgProfileRepository implements RpgProfileRepository {
  SupabaseRpgProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RpgProfile> getMyProfile(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Utilisateur non connecté.');

    final memberResponse = await _client
        .from('family_members')
        .select('''
            id,
            user_id,
            role,
            level,
            xp,
            gold,
            profile:profiles!family_members_user_id_fkey(
              display_name,
              avatar_key
            ),
            family:families!family_members_family_id_fkey(
              owner_id,
              kingdom_name
            )
          ''')
        .eq('family_id', familyId)
        .eq('user_id', user.id)
        .eq('is_active', true)
        .single();

    final memberData = Map<String, dynamic>.from(memberResponse);
    final memberId = memberData['id'] as String;

    final results = await Future.wait<dynamic>([
      _client.from('skills').select().order('name'),
      _client
          .from('member_skills')
          .select('skill_id, xp, level')
          .eq('member_id', memberId),
      _client
          .from('quest_completions')
          .select('''
            completed_at,
            approved_at,
            quest:quests!quest_completions_quest_id_fkey(
              title,
              xp_reward,
              gold_reward,
              boss_damage
            )
          ''')
          .eq('completed_by', memberId)
          .eq('status', 'approved')
          .order('approved_at', ascending: false)
          .limit(5),
    ]);

    final progressBySkill = <String, Map<String, dynamic>>{};
    for (final item in results[1] as List) {
      final progress = Map<String, dynamic>.from(item as Map);
      final id = _canonicalSkillId(progress['skill_id'] as String);
      final previous = progressBySkill[id];
      progressBySkill[id] = {
        'xp': (previous?['xp'] as num? ?? 0) + (progress['xp'] as num? ?? 0),
        'level': [
          (previous?['level'] as num? ?? 1).toInt(),
          (progress['level'] as num? ?? 1).toInt(),
        ].reduce((left, right) => left > right ? left : right),
      };
    }

    final skillCatalog = <String, Map<String, dynamic>>{};
    for (final item in results[0] as List) {
      final skillData = Map<String, dynamic>.from(item as Map);
      final id = _canonicalSkillId(skillData['id'] as String);
      if (!_heroicSkillIds.contains(id)) continue;
      skillCatalog[id] = {...skillData, 'id': id};
    }

    final skills = skillCatalog.values.map((skillData) {
      final progress = progressBySkill[skillData['id'] as String];
      return RpgSkill.fromMap({
        ...skillData,
        'xp': progress?['xp'] ?? 0,
        'level': progress?['level'] ?? 1,
      });
    }).toList()
      ..sort((left, right) {
        final byXp = right.xp.compareTo(left.xp);
        return byXp != 0 ? byXp : left.name.compareTo(right.name);
      });

    final profileData = Map<String, dynamic>.from(memberData['profile'] as Map);
    final familyData = Map<String, dynamic>.from(memberData['family'] as Map);

    return RpgProfile(
      memberId: memberId,
      userId: memberData['user_id'] as String,
      displayName: profileData['display_name'] as String,
      avatarKey: profileData['avatar_key'] as String?,
      role: memberData['role'] as String,
      level: (memberData['level'] as num).toInt(),
      xp: (memberData['xp'] as num).toInt(),
      gold: (memberData['gold'] as num).toInt(),
      kingdomName: familyData['kingdom_name'] as String,
      isOwner: familyData['owner_id'] == user.id,
      skills: skills,
      recentAdventures: (results[2] as List)
          .where((item) {
            final data = Map<String, dynamic>.from(item as Map);
            return data['quest'] != null;
          })
          .map((item) => RpgAdventure.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }

  @override
  Future<void> updateMyProfile({
    required String displayName,
    required String avatarKey,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Utilisateur non connecté.');

    final normalizedName = displayName.trim();
    if (normalizedName.length < 2 || normalizedName.length > 32) {
      throw ArgumentError('Le nom doit contenir entre 2 et 32 caractères.');
    }
    if (!rpgAvatarKeys.contains(avatarKey)) {
      throw ArgumentError('Cet avatar n’est pas disponible.');
    }

    await _client.from('profiles').update({
      'display_name': normalizedName,
      'avatar_key': avatarKey,
    }).eq('id', user.id);
  }
}

const rpgAvatars = <String, String>{
  'guardian': '🛡️',
  'knight': '⚔️',
  'mage': '🧙',
  'ranger': '🏹',
  'healer': '💚',
  'scholar': '📚',
  'explorer': '🧭',
  'druid': '🌿',
  'cook': '🍳',
  'builder': '🔨',
  'star': '⭐',
  'dragon': '🐉',
};

Set<String> get rpgAvatarKeys => rpgAvatars.keys.toSet();

String avatarEmoji(String? key) => rpgAvatars[key] ?? '🧭';

String _canonicalSkillId(String id) {
  return id == 'organisation' ? 'organization' : id;
}

const _heroicSkillIds = <String>{
  'strength',
  'agility',
  'intelligence',
  'leadership',
  'endurance',
  'dexterity',
  'cleaning',
  'organization',
  'cooking',
  'gardening',
};
