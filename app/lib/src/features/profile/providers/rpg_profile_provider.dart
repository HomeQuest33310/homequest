import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/rpg_profile_repository.dart';
import '../data/rpg_profile_repository_impl.dart';
import '../domain/rpg_profile.dart';

final rpgProfileRepositoryProvider = Provider<RpgProfileRepository>((ref) {
  return SupabaseRpgProfileRepository(ref.watch(supabaseProvider));
});

final currentRpgProfileProvider = FutureProvider<RpgProfile>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) throw StateError('Aucun royaume actif.');
  return ref.watch(rpgProfileRepositoryProvider).getMyProfile(family.id);
});

final familyRpgProfilesProvider = FutureProvider<List<RpgProfile>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];

  final members = await ref.watch(currentFamilyMembersProvider.future);
  final repository = ref.watch(rpgProfileRepositoryProvider);
  return Future.wait(
    members.map(
      (member) => repository.getMemberProfile(
        familyId: family.id,
        memberId: member.id,
      ),
    ),
  );
});

final rpgProfileControllerProvider =
    StateNotifierProvider<RpgProfileController, AsyncValue<void>>((ref) {
  return RpgProfileController(ref);
});

class RpgProfileController extends StateNotifier<AsyncValue<void>> {
  RpgProfileController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> updateProfile({
    required String displayName,
    required String avatarKey,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref.read(rpgProfileRepositoryProvider).updateMyProfile(
            displayName: displayName,
            avatarKey: avatarKey,
          );
      _ref.invalidate(currentRpgProfileProvider);
      _ref.invalidate(currentFamilyMembersProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
