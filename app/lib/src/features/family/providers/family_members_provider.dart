import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../domain/family_member.dart';
import 'family_provider.dart';

final currentFamilyMembersProvider =
    FutureProvider<List<FamilyMember>>((ref) async {
  final kingdom = await ref.watch(currentKingdomProvider.future);

  if (kingdom == null) {
    return const [];
  }

  return ref.watch(familyRepositoryProvider).getMembers(kingdom.id);
});

final currentFamilyMemberProvider = FutureProvider<FamilyMember?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final members = await ref.watch(currentFamilyMembersProvider.future);
  for (final member in members) {
    if (member.userId == user.id) return member;
  }
  return null;
});

final familyMembersControllerProvider =
    StateNotifierProvider<FamilyMembersController, AsyncValue<void>>((ref) {
  return FamilyMembersController(ref);
});

class FamilyMembersController extends StateNotifier<AsyncValue<void>> {
  FamilyMembersController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> changeRole({
    required String memberId,
    required String kingdomId,
    required String newRole,
  }) async {
    state = const AsyncLoading();

    try {
      await _ref.read(familyRepositoryProvider).changeMemberRole(
            memberId: memberId,
            kingdomId: kingdomId,
            newRole: newRole,
          );

      _ref.invalidate(currentFamilyMembersProvider);
      _ref.invalidate(availableKingdomsProvider);
      _ref.invalidate(currentKingdomProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deactivateMember(String memberId) async {
    state = const AsyncLoading();

    try {
      await _ref.read(familyRepositoryProvider).deactivateMember(memberId);

      _ref.invalidate(currentFamilyMembersProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
