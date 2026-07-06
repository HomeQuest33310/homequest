enum QuestDifficulty { small, normal, large, heroic }

class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.realTask,
    required this.xpReward,
    required this.goldReward,
    required this.bossDamage,
    required this.skillRewards,
  });

  final String id;
  final String title;
  final String realTask;
  final int xpReward;
  final int goldReward;
  final int bossDamage;
  final Map<String, int> skillRewards;
}
