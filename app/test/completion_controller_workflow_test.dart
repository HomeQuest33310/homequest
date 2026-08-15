import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/completions/data/completions_repository.dart';
import 'package:homequestoria/src/features/completions/domain/mission_assignment.dart';
import 'package:homequestoria/src/features/completions/domain/pending_completion.dart';
import 'package:homequestoria/src/features/completions/providers/completions_provider.dart';
import 'package:homequestoria/src/features/quests/providers/quests_provider.dart';

class _FakeCompletionsRepository implements CompletionsRepository {
  final submissions = <String>[];
  final rejections = <String>[];
  final approved = <String>[];

  @override
  Future<CompletionReward?> submit({
    required String questId,
    String? note,
  }) async {
    submissions.add('$questId:${note ?? ''}');
    return const CompletionReward(
      xp: 25,
      gold: 10,
      bossDamage: 3,
      level: 4,
      bossDefeated: false,
    );
  }

  @override
  Future<void> reject({
    required String completionId,
    required String reason,
  }) async {
    rejections.add('$completionId:$reason');
  }

  @override
  Future<CompletionReward> approve(String completionId) async {
    approved.add(completionId);
    return const CompletionReward(
      xp: 25,
      gold: 10,
      bossDamage: 3,
      level: 4,
      bossDefeated: false,
    );
  }

  @override
  Future<List<MissionAssignment>> listMyMissions(String familyId) async => [];

  @override
  Future<void> leave(String questId) async {}

  @override
  Future<List<PendingCompletion>> listPending(String familyId) async => [];
}

ProviderContainer _container(_FakeCompletionsRepository repository) {
  return ProviderContainer(
    overrides: [
      completionsRepositoryProvider.overrideWithValue(repository),
      currentFamilyQuestsProvider.overrideWith((ref) async => const []),
    ],
  );
}

void main() {
  test('une quête refusée peut être resoumise avec ses nouvelles données',
      () async {
    final repository = _FakeCompletionsRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(completionControllerProvider.notifier);

    expect(
      await controller.reject(
        completionId: 'completion-1',
        reason: 'Photo insuffisante',
      ),
      isTrue,
    );
    expect(await controller.submit(questId: 'quest-1', note: 'Nouvelle photo'),
        isTrue);

    expect(repository.rejections, ['completion-1:Photo insuffisante']);
    expect(repository.submissions, ['quest-1:Nouvelle photo']);
    expect(controller.lastReward?.xp, 25);
    expect(controller.lastReward?.gold, 10);
  });

  test('la validation expose les récompenses de la quête terminée', () async {
    final repository = _FakeCompletionsRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(completionControllerProvider.notifier);

    expect(await controller.approve('completion-once'), isTrue);

    expect(repository.approved, ['completion-once']);
    expect(controller.lastReward?.xp, 25);
    expect(controller.lastReward?.gold, 10);
    expect(controller.lastReward?.bossDamage, 3);
  });
}
