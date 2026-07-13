import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../chronicles/providers/chronicles_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../family/providers/family_stats_provider.dart';
import '../data/completions_repository.dart';
import '../data/completions_repository_impl.dart';
import '../domain/mission_assignment.dart';
import '../domain/pending_completion.dart';

final completionsRepositoryProvider = Provider<CompletionsRepository>((ref) {
  return SupabaseCompletionsRepository(ref.watch(supabaseProvider));
});

final myMissionsProvider = FutureProvider<List<MissionAssignment>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];
  return ref.watch(completionsRepositoryProvider).listMyMissions(family.id);
});

final pendingCompletionsProvider =
    FutureProvider<List<PendingCompletion>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  final member = await ref.watch(currentFamilyMemberProvider.future);
  if (family == null || member?.role != 'guardian') return const [];
  return ref.watch(completionsRepositoryProvider).listPending(family.id);
});

final completionControllerProvider =
    StateNotifierProvider<CompletionController, AsyncValue<void>>((ref) {
  return CompletionController(ref);
});

class CompletionController extends StateNotifier<AsyncValue<void>> {
  CompletionController(this._ref) : super(const AsyncData(null));

  final Ref _ref;
  CompletionReward? lastReward;

  Future<bool> submit({required String questId, String? note}) async {
    state = const AsyncLoading();
    try {
      lastReward = await _ref.read(completionsRepositoryProvider).submit(
            questId: questId,
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

  Future<bool> approve(String completionId) async {
    state = const AsyncLoading();
    try {
      lastReward =
          await _ref.read(completionsRepositoryProvider).approve(completionId);
      _refresh();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> reject({
    required String completionId,
    required String reason,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref.read(completionsRepositoryProvider).reject(
            completionId: completionId,
            reason: reason,
          );
      lastReward = null;
      _refresh();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  void _refresh() {
    _ref.invalidate(myMissionsProvider);
    _ref.invalidate(pendingCompletionsProvider);
    _ref.invalidate(currentFamilyMembersProvider);
    _ref.invalidate(currentFamilyStatsProvider);
    _ref.invalidate(recentChroniclesProvider);
  }
}
