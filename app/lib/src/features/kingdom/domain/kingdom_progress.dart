import '../../family/providers/family_stats_provider.dart';

class KingdomProgress {
  const KingdomProgress({
    required this.stage,
    required this.nextStage,
    required this.stageProgress,
    required this.buildings,
  });

  factory KingdomProgress.fromStats(FamilyStats stats) {
    final currentStage = KingdomStage.forQuestCount(stats.approvedQuestCount);
    final nextStage = KingdomStage.nextAfter(currentStage);
    final progress = nextStage == null
        ? 1.0
        : ((stats.approvedQuestCount - currentStage.requiredQuests) /
                (nextStage.requiredQuests - currentStage.requiredQuests))
            .clamp(0, 1)
            .toDouble();

    return KingdomProgress(
      stage: currentStage,
      nextStage: nextStage,
      stageProgress: progress,
      buildings: [
        KingdomBuilding.quests(
          emoji: '⛺',
          name: 'Campement des Héros',
          description: 'Le premier refuge de la guilde.',
          required: 0,
          current: stats.approvedQuestCount,
        ),
        KingdomBuilding.quests(
          emoji: '🍲',
          name: 'Taverne du Banquet',
          description: 'Un lieu chaleureux où partager les récits de mission.',
          required: 10,
          current: stats.approvedQuestCount,
        ),
        KingdomBuilding.quests(
          emoji: '⚒️',
          name: 'Forge des Aventuriers',
          description: 'Les efforts de la guilde y deviennent des légendes.',
          required: 25,
          current: stats.approvedQuestCount,
        ),
        KingdomBuilding.quests(
          emoji: '📚',
          name: 'Grande Bibliothèque',
          description: 'Elle conserve le savoir et les Chroniques du Royaume.',
          required: 50,
          current: stats.approvedQuestCount,
        ),
        KingdomBuilding.bosses(
          emoji: '🏛️',
          name: 'Hall des Trophées',
          description: 'Les victoires collectives y sont honorées.',
          required: 3,
          current: stats.defeatedBossCount,
        ),
        KingdomBuilding.rewards(
          emoji: '🌳',
          name: 'Jardin des Souhaits',
          description: 'Les récompenses partagées y font fleurir le Royaume.',
          required: 3,
          current: stats.deliveredRewardCount,
        ),
        KingdomBuilding.quests(
          emoji: '🏰',
          name: 'Château de la Guilde',
          description: 'Le symbole d’un Royaume uni et persévérant.',
          required: 100,
          current: stats.approvedQuestCount,
        ),
      ],
    );
  }

  final KingdomStage stage;
  final KingdomStage? nextStage;
  final double stageProgress;
  final List<KingdomBuilding> buildings;

  int get unlockedBuildingCount =>
      buildings.where((building) => building.isUnlocked).length;
}

class KingdomStage {
  const KingdomStage({
    required this.name,
    required this.emoji,
    required this.requiredQuests,
  });

  final String name;
  final String emoji;
  final int requiredQuests;

  static const values = [
    KingdomStage(name: 'Campement', emoji: '⛺', requiredQuests: 0),
    KingdomStage(name: 'Hameau', emoji: '🏕️', requiredQuests: 10),
    KingdomStage(name: 'Village', emoji: '🏘️', requiredQuests: 25),
    KingdomStage(name: 'Bourg', emoji: '🏠', requiredQuests: 50),
    KingdomStage(name: 'Cité', emoji: '🏰', requiredQuests: 100),
    KingdomStage(name: 'Grand Royaume', emoji: '👑', requiredQuests: 200),
  ];

  static KingdomStage forQuestCount(int count) {
    return values.lastWhere(
      (stage) => count >= stage.requiredQuests,
      orElse: () => values.first,
    );
  }

  static KingdomStage? nextAfter(KingdomStage stage) {
    final index = values.indexOf(stage);
    return index < 0 || index == values.length - 1 ? null : values[index + 1];
  }
}

enum KingdomBuildingGoal { quests, bosses, rewards }

class KingdomBuilding {
  const KingdomBuilding._({
    required this.emoji,
    required this.name,
    required this.description,
    required this.goal,
    required this.required,
    required this.current,
  });

  factory KingdomBuilding.quests({
    required String emoji,
    required String name,
    required String description,
    required int required,
    required int current,
  }) =>
      KingdomBuilding._(
        emoji: emoji,
        name: name,
        description: description,
        goal: KingdomBuildingGoal.quests,
        required: required,
        current: current,
      );

  factory KingdomBuilding.bosses({
    required String emoji,
    required String name,
    required String description,
    required int required,
    required int current,
  }) =>
      KingdomBuilding._(
        emoji: emoji,
        name: name,
        description: description,
        goal: KingdomBuildingGoal.bosses,
        required: required,
        current: current,
      );

  factory KingdomBuilding.rewards({
    required String emoji,
    required String name,
    required String description,
    required int required,
    required int current,
  }) =>
      KingdomBuilding._(
        emoji: emoji,
        name: name,
        description: description,
        goal: KingdomBuildingGoal.rewards,
        required: required,
        current: current,
      );

  final String emoji;
  final String name;
  final String description;
  final KingdomBuildingGoal goal;
  final int required;
  final int current;

  bool get isUnlocked => current >= required;
  double get progress =>
      required <= 0 ? 1 : (current / required).clamp(0, 1).toDouble();

  String get goalLabel {
    switch (goal) {
      case KingdomBuildingGoal.bosses:
        return '$current/$required boss vaincus';
      case KingdomBuildingGoal.rewards:
        return '$current/$required récompenses remises';
      case KingdomBuildingGoal.quests:
        return '$current/$required quêtes accomplies';
    }
  }
}
