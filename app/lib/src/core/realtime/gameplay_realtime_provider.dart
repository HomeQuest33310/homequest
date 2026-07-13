import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/chronicles/providers/chronicles_provider.dart';
import '../../features/completions/providers/completions_provider.dart';
import '../../features/family/providers/family_members_provider.dart';
import '../../features/family/providers/family_provider.dart';
import '../../features/family/providers/family_stats_provider.dart';
import '../../features/notifications/providers/notifications_provider.dart';
import '../../features/quests/providers/quests_provider.dart';

final gameplayRealtimeProvider = Provider<void>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  final user = ref.watch(currentUserProvider);
  if (family == null || user == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client.channel(
    'homequest-gameplay-${family.id}-${user.id}',
  );

  void refreshGameplay(PostgresChangePayload payload) {
    ref.invalidate(currentFamilyQuestsProvider);
    ref.invalidate(myMissionsProvider);
    ref.invalidate(pendingCompletionsProvider);
    ref.invalidate(currentFamilyMembersProvider);
    ref.invalidate(currentFamilyStatsProvider);
    ref.invalidate(recentChroniclesProvider);
    ref.invalidate(guardianNotificationsProvider);
  }

  for (final table in const [
    'quests',
    'quest_assignments',
    'quest_completions',
    'family_members',
    'member_skills',
    'bosses',
    'boss_damage_events',
    'chronicles',
    'guardian_notifications',
  ]) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: refreshGameplay,
    );
  }

  channel.subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
