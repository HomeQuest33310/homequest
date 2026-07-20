import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../chronicles/providers/chronicles_provider.dart';
import '../../domains/providers/domains_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../data/family_repository.dart';
import '../data/family_repository_impl.dart';
import '../domain/family.dart' as domain;

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return SupabaseFamilyRepository(ref.watch(supabaseProvider));
});

final currentFamilyProvider = FutureProvider<domain.Family?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final kingdom = await ref.watch(currentKingdomProvider.future);
  if (kingdom == null) return null;
  return ref.watch(familyRepositoryProvider).getFamilyById(kingdom.familyId);
});

final createFamilyControllerProvider =
    StateNotifierProvider<CreateFamilyController, AsyncValue<void>>((ref) {
  return CreateFamilyController(ref);
});

final leaveKingdomControllerProvider =
    StateNotifierProvider<LeaveKingdomController, AsyncValue<void>>((ref) {
  return LeaveKingdomController(ref);
});

class LeaveKingdomController extends StateNotifier<AsyncValue<void>> {
  LeaveKingdomController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> leaveKingdom(String kingdomId) async {
    state = const AsyncLoading();
    try {
      await _ref.read(familyRepositoryProvider).leaveKingdom(kingdomId);
      _ref.read(selectedKingdomIdProvider.notifier).state = null;
      _ref.invalidate(availableKingdomsProvider);
      _ref.invalidate(currentKingdomProvider);
      _ref.invalidate(currentFamilyProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

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
      final createdFamily =
          await _ref.read(familyRepositoryProvider).createFamily(
            familyName: familyName,
            kingdomName: kingdomName,
            primaryDomainName: primaryDomainName,
            ownerId: user.id,
          );
      _ref.invalidate(currentFamilyProvider);
      _ref.invalidate(currentFamilyDomainsProvider);
      _ref.invalidate(recentChroniclesProvider);
      _ref.invalidate(availableKingdomsProvider);
      _ref.invalidate(currentKingdomProvider);

      // Make the newly created kingdom immediately active, even when the
      // user already belongs to other kingdoms.
      final kingdoms = await _ref.refresh(availableKingdomsProvider.future);
      final createdKingdom = kingdoms.where(
        (kingdom) => kingdom.familyId == createdFamily.id,
      );
      if (createdKingdom.isNotEmpty) {
        _ref.read(selectedKingdomIdProvider.notifier).state =
            createdKingdom.first.id;
      }
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
