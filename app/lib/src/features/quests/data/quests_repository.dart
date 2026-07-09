import '../domain/quest.dart';

abstract class QuestsRepository {
  Future<List<Quest>> listQuests(String familyId);

  Future<Quest> createQuest({
    required String familyId,
    required String domainId,
    required String title,
    required String realTask,
    String? description,
    required int xpReward,
    required int goldReward,
    required int bossDamage,
    required String frequency,
  });

  Future<Quest> updateQuest({
    required String questId,
    required String title,
    required String realTask,
    String? description,
    String? domainId,
    required int xpReward,
    required int goldReward,
    required int bossDamage,
    required String frequency,
  });

    Future<void> assignQuest({
      required String questId,
      required String memberId,
  });
  Future<Quest> archiveQuest(String questId);

}