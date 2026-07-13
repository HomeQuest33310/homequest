import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domains/providers/domains_provider.dart';
import '../domain/family_invitation.dart';
import 'family_members_provider.dart';
import 'family_provider.dart';

final currentFamilyInvitationsProvider =
    FutureProvider<List<FamilyInvitation>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];

  return ref.watch(familyRepositoryProvider).getInvitations(family.id);
});

final familyInvitationsControllerProvider =
    StateNotifierProvider<FamilyInvitationsController, AsyncValue<void>>((ref) {
  return FamilyInvitationsController(ref);
});

class FamilyInvitationsController extends StateNotifier<AsyncValue<void>> {
  FamilyInvitationsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<FamilyInvitation?> invite({
    required String email,
    required String role,
    required String membershipScope,
    String? domainId,
    int expiresInDays = 7,
  }) async {
    final family = await _ref.read(currentFamilyProvider.future);
    if (family == null) {
      state = AsyncError('Aucun royaume actif', StackTrace.current);
      return null;
    }

    state = const AsyncLoading();
    try {
      final invitation = await _ref.read(familyRepositoryProvider).inviteMember(
            familyId: family.id,
            email: email,
            role: role,
            membershipScope: membershipScope,
            domainId: domainId,
            expiresInDays: expiresInDays,
          );
      _ref.invalidate(currentFamilyInvitationsProvider);
      state = const AsyncData(null);
      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<bool> cancel(String invitationId) async {
    state = const AsyncLoading();
    try {
      await _ref.read(familyRepositoryProvider).cancelInvitation(invitationId);
      _ref.invalidate(currentFamilyInvitationsProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> accept(String token) async {
    state = const AsyncLoading();
    try {
      await _ref.read(familyRepositoryProvider).acceptInvitation(token);
      _ref.invalidate(currentFamilyProvider);
      _ref.invalidate(currentFamilyMembersProvider);
      _ref.invalidate(currentFamilyDomainsProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
