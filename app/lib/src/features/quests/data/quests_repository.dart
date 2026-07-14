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
    required String emoji,
    required String element,
    required int difficulty,
    required String regionKey,
    required List<QuestSkillReward> skillRewards,
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
    required String emoji,
    required String element,
    required int difficulty,
    required String regionKey,
    required List<QuestSkillReward> skillRewards,
  });

  Future<Quest> archiveQuest(String questId);

  Future<void> assignQuest({
    required String questId,
    required String memberId,
  });

  Future<void> selfAssignQuest(String questId);
}
