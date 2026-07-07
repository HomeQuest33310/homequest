import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'family_provider.dart';

class FamilyStats {
  const FamilyStats({
    required this.memberCount,
    required this.domainCount,
    required this.chronicleCount,
  });

  final int memberCount;
  final int domainCount;
  final int chronicleCount;
}

final currentFamilyStatsProvider = FutureProvider<FamilyStats>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) {
    return const FamilyStats(memberCount: 0, domainCount: 0, chronicleCount: 0);
  }

  final client = ref.watch(supabaseProvider);

  final members = await client
      .from('family_members')
      .select('id')
      .eq('family_id', family.id);

  final domains = await client
      .from('domains')
      .select('id')
      .eq('family_id', family.id);

  final chronicles = await client
      .from('chronicles')
      .select('id')
      .eq('family_id', family.id);

  return FamilyStats(
    memberCount: members.length,
    domainCount: domains.length,
    chronicleCount: chronicles.length,
  );
});
