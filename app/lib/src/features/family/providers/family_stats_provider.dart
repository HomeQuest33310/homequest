import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'family_provider.dart';

class FamilyStats {
  const FamilyStats({
    required this.memberCount,
    required this.domainCount,
    required this.chronicleCount,
    required this.approvedQuestCount,
    required this.defeatedBossCount,
    required this.deliveredRewardCount,
  });

  final int memberCount;
  final int domainCount;
  final int chronicleCount;
  final int approvedQuestCount;
  final int defeatedBossCount;
  final int deliveredRewardCount;
}

final currentFamilyStatsProvider = FutureProvider<FamilyStats>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) {
    return const FamilyStats(
      memberCount: 0,
      domainCount: 0,
      chronicleCount: 0,
      approvedQuestCount: 0,
      defeatedBossCount: 0,
      deliveredRewardCount: 0,
    );
  }

  final client = ref.watch(supabaseProvider);

  final members = await client
      .from('family_members')
      .select('id')
      .eq('family_id', family.id);

  final domains =
      await client.from('domains').select('id').eq('family_id', family.id);

  final chronicles =
      await client.from('chronicles').select('id').eq('family_id', family.id);

  final approvedQuests = await client
      .from('quest_completions')
      .select('quest:quests!quest_completions_quest_id_fkey!inner(family_id)')
      .eq('status', 'approved')
      .eq('quest.family_id', family.id);

  final defeatedBosses = await client
      .from('bosses')
      .select('id')
      .eq('family_id', family.id)
      .eq('status', 'defeated');

  final deliveredRewards = await client
      .from('reward_suggestions')
      .select('id')
      .eq('family_id', family.id)
      .not('delivered_at', 'is', null);

  return FamilyStats(
    memberCount: members.length,
    domainCount: domains.length,
    chronicleCount: chronicles.length,
    approvedQuestCount: approvedQuests.length,
    defeatedBossCount: defeatedBosses.length,
    deliveredRewardCount: deliveredRewards.length,
  );
});
