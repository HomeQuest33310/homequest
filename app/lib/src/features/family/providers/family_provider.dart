import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../chronicles/providers/chronicles_provider.dart';
import '../../domains/providers/domains_provider.dart';
import '../data/family_repository.dart';
import '../data/family_repository_impl.dart';
import '../domain/family.dart' as domain;
import '../domain/family_member.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return SupabaseFamilyRepository(ref.watch(supabaseProvider));
});

final currentFamilyProvider = FutureProvider<domain.Family?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(familyRepositoryProvider).getCurrentUserFamily(user.id);
});

final createFamilyControllerProvider =
    StateNotifierProvider<CreateFamilyController, AsyncValue<void>>((ref) {
  return CreateFamilyController(ref);
});

class CreateFamilyController extends StateNotifier<AsyncValue<void>> {
  CreateFamilyController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> createFamily({
    required String familyName,
    required String kingdomName,
    required String primaryDomainName,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError('Utilisateur non connecté', StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    try {
      await _ref.read(familyRepositoryProvider).createFamily(
            familyName: familyName,
            kingdomName: kingdomName,
            primaryDomainName: primaryDomainName,
            ownerId: user.id,
          );
      _ref.invalidate(currentFamilyProvider);
      _ref.invalidate(currentFamilyDomainsProvider);
      _ref.invalidate(recentChroniclesProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
  final currentFamilyMembersProvider =
    FutureProvider<List<FamilyMember>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);

  if (family == null) return [];

  return ref
      .watch(familyRepositoryProvider)
      .getMembers(family.id);
});
}
