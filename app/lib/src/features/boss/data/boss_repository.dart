import '../domain/boss.dart';

abstract class BossRepository {
  Future<List<Boss>> listBosses(String kingdomId);

  Future<Boss> createBoss({
    required String familyId,
    required String kingdomId,
    required String name,
    required String emoji,
    required String element,
    required String domainLabel,
    required String description,
    required int maxHp,
    required int difficulty,
    required int requiredLevel,
    required int xpReward,
    required String specialItem,
    required List<BossSkillReward> skillRewards,
    required bool replaceActive,
  });

  Future<void> retireBoss(String bossId);
}
