import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../chronicles/providers/chronicles_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/quests_repository.dart';
import '../data/quests_repository_impl.dart';
import '../domain/quest.dart';

final questsRepositoryProvider = Provider<QuestsRepository>((ref) {
  return SupabaseQuestsRepository(ref.watch(supabaseProvider));
});

final currentFamilyQuestsProvider = FutureProvider<List<Quest>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];

  return ref.watch(questsRepositoryProvider).listQuests(family.id);
});

final createQuestControllerProvider =
    StateNotifierProvider<CreateQuestController, AsyncValue<void>>((ref) {
  return CreateQuestController(ref);
});

final updateQuestControllerProvider =
    StateNotifierProvider<UpdateQuestController, AsyncValue<void>>((ref) {
  return UpdateQuestController(ref);
});

final assignQuestControllerProvider =
    StateNotifierProvider<AssignQuestController, AsyncValue<void>>((ref) {
  return AssignQuestController(ref);
});

final selfAssignQuestControllerProvider =
    StateNotifierProvider<SelfAssignQuestController, AsyncValue<void>>((ref) {
  return SelfAssignQuestController(ref);
});

class CreateQuestController extends StateNotifier<AsyncValue<void>> {
  CreateQuestController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> createQuest({
    required String title,
    required String realTask,
    required String domainId,
    required int xpReward,
    required int goldReward,
    required int bossDamage,
    required String frequency,
    String? description,
  }) async {
    final family = await _ref.read(currentFamilyProvider.future);
    if (family == null) {
      state = AsyncError('Aucun royaume actif', StackTrace.current);
      return;
    }

    state = const AsyncLoading();

    try {
      await _ref.read(questsRepositoryProvider).createQuest(
            familyId: family.id,
            domainId: domainId,
            title: title,
            realTask: realTask,
            description: description,
            xpReward: xpReward,
            goldReward: goldReward,
            bossDamage: bossDamage,
            frequency: frequency,
          );

      _ref.invalidate(currentFamilyQuestsProvider);
      _ref.invalidate(recentChroniclesProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

class UpdateQuestController extends StateNotifier<AsyncValue<void>> {
  UpdateQuestController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> updateQuest({
    required String questId,
    required String title,
    required String realTask,
    required String domainId,
    required int xpReward,
    required int goldReward,
    required int bossDamage,
    required String frequency,
    String? description,
  }) async {
    state = const AsyncLoading();

    try {
      await _ref.read(questsRepositoryProvider).updateQuest(
            questId: questId,
            title: title,
            realTask: realTask,
            description: description,
            domainId: domainId,
            xpReward: xpReward,
            goldReward: goldReward,
            bossDamage: bossDamage,
            frequency: frequency,
          );

      _ref.invalidate(currentFamilyQuestsProvider);
      _ref.invalidate(recentChroniclesProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> archiveQuest(String questId) async {
    state = const AsyncLoading();

    try {
      await _ref.read(questsRepositoryProvider).archiveQuest(questId);

      _ref.invalidate(currentFamilyQuestsProvider);
      _ref.invalidate(recentChroniclesProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

class AssignQuestController extends StateNotifier<AsyncValue<void>> {
  AssignQuestController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> assignQuest({
    required String questId,
    required String memberId,
  }) async {
    state = const AsyncLoading();

    try {
      await _ref.read(questsRepositoryProvider).assignQuest(
            questId: questId,
            memberId: memberId,
          );

      _ref.invalidate(currentFamilyQuestsProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

class SelfAssignQuestController extends StateNotifier<AsyncValue<void>> {
  SelfAssignQuestController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> selfAssignQuest(String questId) async {
    state = const AsyncLoading();
    try {
      await _ref.read(questsRepositoryProvider).selfAssignQuest(questId);
      _ref.invalidate(currentFamilyQuestsProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
