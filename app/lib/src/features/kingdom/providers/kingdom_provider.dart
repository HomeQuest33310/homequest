import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../domain/kingdom.dart';

final selectedKingdomIdProvider = StateProvider<String?>((ref) => null);

final kingdomMembershipRealtimeProvider = Provider.autoDispose<void>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client
      .channel('kingdom-memberships:${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'kingdom_members',
        callback: (_) {
          ref.invalidate(availableKingdomsProvider);
          ref.invalidate(currentKingdomProvider);
        },
      )
      .subscribe();

  ref.onDispose(() => client.removeChannel(channel));
});

final availableKingdomsProvider = FutureProvider<List<Kingdom>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  final data =
      await ref.watch(supabaseProvider).from('kingdom_members').select('''
    role,
    membership_scope,
    domain_id,
    expires_at,
    member:family_members!kingdom_members_member_id_fkey!inner(user_id),
    kingdom:kingdoms!kingdom_members_kingdom_id_fkey!inner(
      id,
      family_id,
      name,
      kind,
      icon,
      description,
      is_primary,
      created_at,
      archived_at
    )
  ''').eq('member.user_id', user.id).eq('is_active', true);

  final kingdoms = (data as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .where((row) => row['kingdom'] != null)
      .where((row) {
    final expiresAt = row['expires_at'] as String?;
    return expiresAt == null ||
        DateTime.parse(expiresAt).isAfter(DateTime.now());
  }).where((row) {
    final kingdom = Map<String, dynamic>.from(row['kingdom'] as Map);
    return kingdom['archived_at'] == null;
  }).map((row) {
    final kingdom = Map<String, dynamic>.from(row['kingdom'] as Map);
    kingdom['membership_role'] = row['role'];
    kingdom['membership_scope'] = row['membership_scope'];
    kingdom['membership_domain_id'] = row['domain_id'];
    kingdom['membership_expires_at'] = row['expires_at'];
    return Kingdom.fromMap(kingdom);
  }).toList()
    ..sort((left, right) {
      if (left.isPrimary != right.isPrimary) return left.isPrimary ? -1 : 1;
      return left.name.compareTo(right.name);
    });
  return kingdoms;
});

final currentKingdomProvider = FutureProvider<Kingdom?>((ref) async {
  final kingdoms = await ref.watch(availableKingdomsProvider.future);
  if (kingdoms.isEmpty) return null;

  final selectedId = ref.watch(selectedKingdomIdProvider);
  for (final kingdom in kingdoms) {
    if (kingdom.id == selectedId) return kingdom;
  }
  return kingdoms.first;
});
