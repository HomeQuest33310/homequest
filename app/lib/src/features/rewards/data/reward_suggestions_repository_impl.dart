import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reward_suggestion.dart';
import 'reward_suggestions_repository.dart';

class SupabaseRewardSuggestionsRepository
    implements RewardSuggestionsRepository {
  SupabaseRewardSuggestionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RewardSuggestion>> listSuggestions(String familyId) async {
    final data = await _client.from('reward_suggestions').select('''
          id,
          title,
          description,
          suggested_quest_count,
          status,
          guardian_title,
          guardian_description,
          guardian_quest_count,
          guardian_boss_theme,
          boss_id,
          completed_quest_count,
          fulfilled_at,
          delivered_at,
          created_by_guardian,
          created_at,
          proposer:family_members!reward_suggestions_proposed_by_fkey(
            id,
            profile:profiles!family_members_user_id_fkey(display_name)
          )
        ''').eq('family_id', familyId).order('created_at', ascending: false);

    return (data as List)
        .map(
          (item) => RewardSuggestion.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> propose({
    required String familyId,
    required String memberId,
    required String title,
    required String description,
    required int questCount,
  }) async {
    await _client.from('reward_suggestions').insert({
      'family_id': familyId,
      'proposed_by': memberId,
      'title': title.trim(),
      'description': description.trim(),
      'suggested_quest_count': questCount,
    });
  }

  @override
  Future<void> review({
    required String suggestionId,
    required String status,
    required String title,
    required String description,
    required int? questCount,
    required Map<String, dynamic>? boss,
    required bool replaceActiveBoss,
  }) async {
    await _client.rpc(
      'review_reward_suggestion',
      params: {
        'p_suggestion_id': suggestionId,
        'p_status': status,
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_quest_count': questCount,
        'p_boss': boss,
        'p_replace_active_boss': replaceActiveBoss,
      },
    );
  }

  @override
  Future<void> createGuardianGoal({
    required String familyId,
    required String title,
    required String description,
    required int? questCount,
    required Map<String, dynamic>? boss,
    required bool replaceActiveBoss,
  }) async {
    await _client.rpc(
      'create_guardian_reward_goal',
      params: {
        'p_family_id': familyId,
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_quest_count': questCount,
        'p_boss': boss,
        'p_replace_active_boss': replaceActiveBoss,
      },
    );
  }

  @override
  Future<void> deliverCollectiveReward(String suggestionId) async {
    await _client.rpc(
      'deliver_collective_reward',
      params: {'p_suggestion_id': suggestionId},
    );
  }
}
