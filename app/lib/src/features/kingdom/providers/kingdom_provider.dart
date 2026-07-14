import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../domain/kingdom.dart';

final selectedKingdomIdProvider = StateProvider<String?>((ref) => null);

final availableKingdomsProvider = FutureProvider<List<Kingdom>>((ref) async {
  final member = await ref.watch(currentFamilyMemberProvider.future);
  if (member == null) return const [];

  final data =
      await ref.watch(supabaseProvider).from('kingdom_members').select('''
    kingdom:kingdoms!kingdom_members_kingdom_id_fkey!inner(
      id,
      family_id,
      name,
      kind,
      icon,
      description,
      is_primary,
      archived_at
    )
  ''').eq('member_id', member.id).eq('is_active', true);

  final kingdoms = (data as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .where((row) => row['kingdom'] != null)
      .where((row) {
        final kingdom = Map<String, dynamic>.from(row['kingdom'] as Map);
        return kingdom['archived_at'] == null;
      })
      .map(
        (row) => Kingdom.fromMap(
          Map<String, dynamic>.from(row['kingdom'] as Map),
        ),
      )
      .toList()
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
