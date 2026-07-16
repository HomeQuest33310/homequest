import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_avatar.dart';
import '../domain/rpg_profile.dart';
import 'rpg_profile_repository.dart';

class SupabaseRpgProfileRepository implements RpgProfileRepository {
  SupabaseRpgProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RpgProfile> getMyProfile(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Utilisateur non connecté.');

    return _getProfile(familyId: familyId, userId: user.id);
  }

  @override
  Future<RpgProfile> getMemberProfile({
    required String familyId,
    required String memberId,
  }) {
    return _getProfile(familyId: familyId, targetMemberId: memberId);
  }

  Future<RpgProfile> _getProfile({
    required String familyId,
    String? userId,
    String? targetMemberId,
  }) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Utilisateur non connecté.');
    }
    if (userId == null && targetMemberId == null) {
      throw ArgumentError('Un aventurier doit être sélectionné.');
    }

    var memberQuery = _client.from('family_members').select('''
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
          ''').eq('family_id', familyId).eq('is_active', true);

    if (targetMemberId != null) {
      memberQuery = memberQuery.eq('id', targetMemberId);
    } else {
      memberQuery = memberQuery.eq('user_id', userId!);
    }

    final memberResponse = await memberQuery.single();

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
          .limit(10),
      _client
          .from('boss_reward_events')
          .select('''
            boss_id,
            member_id,
            xp_reward,
            awarded_at,
            boss:bosses!boss_reward_events_boss_id_fkey!inner(
              id,
              family_id,
              name,
              emoji,
              element,
              special_item,
              defeated_at
            ),
            member:family_members!boss_reward_events_member_id_fkey(
              id,
              role,
              profile:profiles!family_members_user_id_fkey(
                display_name
              )
            )
          ''')
          .eq('boss.family_id', familyId)
          .order('awarded_at', ascending: false),
      _client
          .from('quest_completions')
          .select('id')
          .eq('completed_by', memberId)
          .eq('status', 'approved'),
      _getUnlockedAvatarKeys(memberData['user_id'] as String),
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
    final bossVictories = _buildBossVictories(
      results[3] as List,
      currentMemberId: memberId,
    );

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
      isOwner: familyData['owner_id'] == memberData['user_id'],
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
      bossVictories: bossVictories,
      approvedQuestCount: (results[4] as List).length,
      unlockedAvatarKeys: results[5] as Set<String>,
    );
  }

  List<RpgBossVictory> _buildBossVictories(
    List<dynamic> rows, {
    required String currentMemberId,
  }) {
    final rowsByBoss = <String, List<Map<String, dynamic>>>{};
    for (final item in rows) {
      final row = Map<String, dynamic>.from(item as Map);
      final bossId = row['boss_id'] as String;
      rowsByBoss.putIfAbsent(bossId, () => []).add(row);
    }

    final victories = <RpgBossVictory>[];
    for (final entry in rowsByBoss.entries) {
      final participantRows = entry.value;
      if (!participantRows.any(
        (row) => row['member_id'] == currentMemberId,
      )) {
        continue;
      }

      final first = participantRows.first;
      final boss = Map<String, dynamic>.from(first['boss'] as Map);
      final participants = <RpgBossParticipant>[];
      for (final row in participantRows) {
        final member = Map<String, dynamic>.from(row['member'] as Map);
        final profile = Map<String, dynamic>.from(member['profile'] as Map);
        participants.add(
          RpgBossParticipant(
            memberId: member['id'] as String,
            displayName: profile['display_name'] as String? ?? 'Aventurier',
            role: member['role'] as String,
          ),
        );
      }

      final awardedAt = first['awarded_at'] as String;
      victories.add(
        RpgBossVictory(
          id: entry.key,
          name: boss['name'] as String,
          emoji: boss['emoji'] as String? ?? '👹',
          element: boss['element'] as String? ?? 'Neutre',
          specialItem: boss['special_item'] as String? ?? '',
          xpReward: (first['xp_reward'] as num?)?.toInt() ?? 0,
          defeatedAt: DateTime.parse(
            boss['defeated_at'] as String? ?? awardedAt,
          ),
          participants: participants,
        ),
      );
    }

    victories.sort(
      (left, right) => right.defeatedAt.compareTo(left.defeatedAt),
    );
    return victories;
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
    if (!profileAvatarKeys.contains(avatarKey)) {
      throw ArgumentError('Cet avatar n’est pas disponible.');
    }

    try {
      await _client.rpc(
        'update_my_profile',
        params: {
          'p_display_name': normalizedName,
          'p_avatar_key': avatarKey,
        },
      );
    } on PostgrestException catch (error) {
      if (!_isMissingAvatarShopObject(error)) rethrow;
      await _client.from('profiles').update({
        'display_name': normalizedName,
        'avatar_key': avatarKey,
      }).eq('id', user.id);
    }
  }

  @override
  Future<int> purchaseAvatar({
    required String familyId,
    required String avatarKey,
  }) async {
    final avatar = profileAvatarFor(avatarKey);
    if (!avatar.isPremium) {
      throw ArgumentError('Cet avatar est déjà disponible gratuitement.');
    }

    dynamic data;
    try {
      data = await _client.rpc(
        'purchase_profile_avatar',
        params: {
          'p_family_id': familyId,
          'p_avatar_key': avatarKey,
        },
      );
    } on PostgrestException catch (error) {
      if (_isMissingAvatarShopObject(error)) {
        throw StateError(
          'La boutique d’avatars n’est pas encore activée sur Supabase.',
        );
      }
      rethrow;
    }
    final result = Map<String, dynamic>.from(data as Map);
    return (result['remaining_gold'] as num).toInt();
  }

  Future<Set<String>> _getUnlockedAvatarKeys(String userId) async {
    try {
      final data = await _client
          .from('profile_avatar_unlocks')
          .select('avatar_key')
          .eq('user_id', userId);
      return (data as List)
          .map(
            (item) =>
                Map<String, dynamic>.from(item as Map)['avatar_key'] as String,
          )
          .toSet();
    } on PostgrestException catch (error) {
      if (_isMissingAvatarShopObject(error)) return {};
      rethrow;
    }
  }

  bool _isMissingAvatarShopObject(PostgrestException error) {
    return error.code == 'PGRST202' ||
        error.code == 'PGRST205' ||
        error.code == '42P01';
  }
}

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
  'combat',
  'defense',
  'precision',
  'cooperation',
  'elemental_mastery',
  'resilience',
  'power',
  'combat_agility',
  'tactics',
  'magic_mastery',
};
