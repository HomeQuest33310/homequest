import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../completions/providers/completions_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../data/voluntary_quest_requests_repository.dart';
import '../data/voluntary_quest_requests_repository_impl.dart';
import '../domain/quest_suggestion.dart';
import '../domain/voluntary_quest_request.dart';
import 'quests_provider.dart';

const voluntaryQuestMinimumLevel = 10;

bool meetsVoluntaryQuestLevel(int level) => level >= voluntaryQuestMinimumLevel;

final canSubmitVoluntaryQuestProvider = Provider<bool>((ref) {
  final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
  final member = ref.watch(currentFamilyMemberProvider).valueOrNull;
  final role = kingdom?.membershipRole ?? member?.role;

  return (role == 'adventurer' || role == 'mercenary') &&
      member?.isActive == true &&
      meetsVoluntaryQuestLevel(member?.level ?? 0);
});

final voluntaryQuestRequestsRepositoryProvider =
    Provider<VoluntaryQuestRequestsRepository>((ref) {
  return SupabaseVoluntaryQuestRequestsRepository(ref.watch(supabaseProvider));
});

final voluntaryQuestRequestsProvider =
    FutureProvider<List<VoluntaryQuestRequest>>((ref) async {
  final kingdom = await ref.watch(currentKingdomProvider.future);
  final member = await ref.watch(currentFamilyMemberProvider.future);
  if (kingdom == null || member == null) return const [];

  final requests = await ref
      .watch(voluntaryQuestRequestsRepositoryProvider)
      .listForKingdom(kingdom.id);

  if (kingdom.membershipRole == 'guardian') return requests;
  return requests.where((request) => request.requestedBy == member.id).toList();
});

final pendingVoluntaryQuestRequestCountProvider = Provider<int>((ref) {
  return ref.watch(voluntaryQuestRequestsProvider).maybeWhen(
        data: (items) =>
            items.where((request) => request.status == 'pending').length,
        orElse: () => 0,
      );
});

final voluntaryQuestRequestsControllerProvider =
    StateNotifierProvider<VoluntaryQuestRequestsController, AsyncValue<void>>(
        (ref) {
  return VoluntaryQuestRequestsController(ref);
});

class VoluntaryQuestRequestsController extends StateNotifier<AsyncValue<void>> {
  VoluntaryQuestRequestsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> submit({
    required String domainId,
    required QuestSuggestion suggestion,
    required bool alreadyCompleted,
    String? note,
  }) async {
    final kingdom = await _ref.read(currentKingdomProvider.future);
    final member = await _ref.read(currentFamilyMemberProvider.future);
    if (kingdom == null ||
        member == null ||
        !meetsVoluntaryQuestLevel(member.level)) {
      state = AsyncError(
        StateError('Aventurier niveau 10 requis.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();
    try {
      await _ref.read(voluntaryQuestRequestsRepositoryProvider).submit(
            kingdomId: kingdom.id,
            domainId: domainId,
            suggestion: suggestion,
            alreadyCompleted: alreadyCompleted,
            note: note,
          );
      _refresh();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> review({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref.read(voluntaryQuestRequestsRepositoryProvider).review(
            requestId: requestId,
            approve: approve,
            note: note,
          );
      _refresh();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  void _refresh() {
    _ref.invalidate(voluntaryQuestRequestsProvider);
    _ref.invalidate(currentFamilyQuestsProvider);
    _ref.invalidate(myMissionsProvider);
    _ref.invalidate(pendingCompletionsProvider);
    _ref.invalidate(currentFamilyMembersProvider);
    _ref.invalidate(guardianNotificationsProvider);
  }
}
