import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/family_member.dart';
import '../providers/family_provider.dart';

final currentFamilyMembersProvider =
    FutureProvider<List<FamilyMember>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);

  if (family == null) {
    return [];
  }

  return ref.watch(familyRepositoryProvider).getMembers(family.id);
});