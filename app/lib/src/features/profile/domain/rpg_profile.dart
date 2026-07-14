class RpgProfile {
  const RpgProfile({
    required this.memberId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.level,
    required this.xp,
    required this.gold,
    required this.kingdomName,
    required this.isOwner,
    required this.skills,
    required this.recentAdventures,
    required this.bossVictories,
    required this.approvedQuestCount,
    this.avatarKey,
  });

  final String memberId;
  final String userId;
  final String displayName;
  final String? avatarKey;
  final String role;
  final int level;
  final int xp;
  final int gold;
  final String kingdomName;
  final bool isOwner;
  final List<RpgSkill> skills;
  final List<RpgAdventure> recentAdventures;
  final List<RpgBossVictory> bossVictories;
  final int approvedQuestCount;

  List<ElementalAspect> get elementalAspects {
    final totals = <String, int>{};
    for (final victory in bossVictories) {
      final element = victory.element.trim();
      if (element.isNotEmpty) {
        totals[element] = (totals[element] ?? 0) + 1;
      }
    }
    return totals.entries
        .map((entry) => ElementalAspect(entry.key, entry.value))
        .toList()
      ..sort((left, right) => right.count.compareTo(left.count));
  }

  List<BossTrophy> get bossTrophies => bossVictories
      .where((victory) => victory.specialItem.trim().isNotEmpty)
      .map(
        (victory) => BossTrophy(
          name: victory.specialItem,
          bossName: victory.name,
          bossEmoji: victory.emoji,
          wonAt: victory.defeatedAt,
        ),
      )
      .toList();

  int get currentLevelXp => xpThresholdForLevel(level);
  int get nextLevelXp => xpThresholdForLevel(level + 1);
  int get xpInCurrentLevel => (xp - currentLevelXp).clamp(0, xp);
  int get xpNeededForLevel => nextLevelXp - currentLevelXp;

  double get levelProgress {
    if (xpNeededForLevel <= 0) return 0;
    return (xpInCurrentLevel / xpNeededForLevel).clamp(0, 1);
  }

  int get developedSkills => skills.where((skill) => skill.xp > 0).length;
  HarmonyRank get harmonyRank => HarmonyRank.fromSkillCount(developedSkills);

  List<RpgAchievement> get achievements => [
        RpgAchievement(
          id: 'first_quest',
          emoji: '🌟',
          title: 'Premier pas héroïque',
          description: 'Accomplir une première quête.',
          current: approvedQuestCount,
          target: 1,
        ),
        RpgAchievement(
          id: 'quest_10',
          emoji: '📜',
          title: 'Aventurier confirmé',
          description: 'Accomplir 10 quêtes.',
          current: approvedQuestCount,
          target: 10,
        ),
        RpgAchievement(
          id: 'quest_25',
          emoji: '🏅',
          title: 'Héros infatigable',
          description: 'Accomplir 25 quêtes.',
          current: approvedQuestCount,
          target: 25,
        ),
        RpgAchievement(
          id: 'first_boss',
          emoji: '⚔️',
          title: 'Pourfendeur de monstres',
          description: 'Participer à la défaite d’un boss.',
          current: bossVictories.length,
          target: 1,
        ),
        RpgAchievement(
          id: 'boss_3',
          emoji: '🐉',
          title: 'Fléau des Titans',
          description: 'Participer à la défaite de 3 boss.',
          current: bossVictories.length,
          target: 3,
        ),
        RpgAchievement(
          id: 'versatile_4',
          emoji: '🌈',
          title: 'Héros aux mille talents',
          description: 'Développer 4 compétences différentes.',
          current: developedSkills,
          target: 4,
        ),
        RpgAchievement(
          id: 'harmony_gold',
          emoji: '✨',
          title: 'Maître de l’Harmonie',
          description: 'Développer 6 compétences différentes.',
          current: developedSkills,
          target: 6,
        ),
        RpgAchievement(
          id: 'trophy_3',
          emoji: '🎒',
          title: 'Gardien des reliques',
          description: 'Remporter 3 objets de boss.',
          current: bossTrophies.length,
          target: 3,
        ),
      ];

  String get roleLabel {
    switch (role) {
      case 'guardian':
        return isOwner ? 'Gardien fondateur' : 'Gardien';
      case 'mercenary':
        return 'Mercenaire';
      default:
        return 'Aventurier';
    }
  }

  String get rpgTitle {
    if (bossVictories.length >= 3) return 'Fléau des Titans';
    if (developedSkills >= 6) return 'Maître de l’Harmonie';
    if (approvedQuestCount >= 25) return 'Héros infatigable';
    if (bossVictories.isNotEmpty) return 'Pourfendeur de monstres';
    if (approvedQuestCount >= 10) return 'Aventurier confirmé';
    final activeSkills = skills.where((skill) => skill.xp > 0).toList()
      ..sort((left, right) => right.xp.compareTo(left.xp));
    if (activeSkills.isNotEmpty) {
      return '${roleLabel.split(' ').first} de ${activeSkills.first.name}';
    }
    return '$roleLabel du Royaume';
  }
}

class RpgAchievement {
  const RpgAchievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
  });

  final String id;
  final String emoji;
  final String title;
  final String description;
  final int current;
  final int target;

  bool get isUnlocked => current >= target;
  double get progress => target <= 0 ? 0 : (current / target).clamp(0, 1);
}

class RpgSkill {
  const RpgSkill({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.xp,
    required this.level,
  });

  factory RpgSkill.fromMap(Map<String, dynamic> map) {
    return RpgSkill(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      description: map['description'] as String? ?? '',
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
    );
  }

  final String id;
  final String name;
  final String icon;
  final String description;
  final int xp;
  final int level;

  int get currentLevelXp => skillXpThresholdForLevel(level);
  int get nextLevelXp => skillXpThresholdForLevel(level + 1);
  double get progress {
    if (level >= 5) return 1;
    final needed = nextLevelXp - currentLevelXp;
    if (needed <= 0) return 0;
    return ((xp - currentLevelXp) / needed).clamp(0, 1);
  }
}

class RpgAdventure {
  const RpgAdventure({
    required this.title,
    required this.completedAt,
    required this.xpReward,
    required this.goldReward,
    required this.bossDamage,
  });

  factory RpgAdventure.fromMap(Map<String, dynamic> map) {
    final quest = Map<String, dynamic>.from(map['quest'] as Map);
    return RpgAdventure(
      title: quest['title'] as String,
      completedAt: DateTime.parse(
        (map['approved_at'] ?? map['completed_at']) as String,
      ),
      xpReward: (quest['xp_reward'] as num).toInt(),
      goldReward: (quest['gold_reward'] as num).toInt(),
      bossDamage: (quest['boss_damage'] as num).toInt(),
    );
  }

  final String title;
  final DateTime completedAt;
  final int xpReward;
  final int goldReward;
  final int bossDamage;
}

class RpgBossVictory {
  const RpgBossVictory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.element,
    required this.specialItem,
    required this.xpReward,
    required this.defeatedAt,
    required this.participants,
  });

  final String id;
  final String name;
  final String emoji;
  final String element;
  final String specialItem;
  final int xpReward;
  final DateTime defeatedAt;
  final List<RpgBossParticipant> participants;
}

class RpgBossParticipant {
  const RpgBossParticipant({
    required this.memberId,
    required this.displayName,
    required this.role,
  });

  final String memberId;
  final String displayName;
  final String role;
}

class ElementalAspect {
  const ElementalAspect(this.element, this.count);

  final String element;
  final int count;

  String get emoji {
    switch (element.toLowerCase()) {
      case 'feu':
        return '🔥';
      case 'eau':
        return '💧';
      case 'air':
        return '🌪️';
      case 'terre':
        return '🪨';
      case 'nature':
        return '🌿';
      case 'lumière':
      case 'lumiere':
        return '✨';
      case 'ombre':
        return '🌑';
      case 'glace':
        return '❄️';
      case 'foudre':
        return '⚡';
      case 'arcane':
        return '🔮';
      default:
        return '💠';
    }
  }
}

class BossTrophy {
  const BossTrophy({
    required this.name,
    required this.bossName,
    required this.bossEmoji,
    required this.wonAt,
  });

  final String name;
  final String bossName;
  final String bossEmoji;
  final DateTime wonAt;
}

enum HarmonyRank {
  awakening,
  bronze,
  silver,
  gold,
  platinum,
  rainbow;

  factory HarmonyRank.fromSkillCount(int count) {
    if (count >= 10) return HarmonyRank.rainbow;
    if (count >= 8) return HarmonyRank.platinum;
    if (count >= 6) return HarmonyRank.gold;
    if (count >= 4) return HarmonyRank.silver;
    if (count >= 2) return HarmonyRank.bronze;
    return HarmonyRank.awakening;
  }

  String get label {
    switch (this) {
      case HarmonyRank.awakening:
        return 'Éveil';
      case HarmonyRank.bronze:
        return 'Bronze';
      case HarmonyRank.silver:
        return 'Argent';
      case HarmonyRank.gold:
        return 'Or';
      case HarmonyRank.platinum:
        return 'Platine';
      case HarmonyRank.rainbow:
        return 'Arc-en-ciel';
    }
  }

  int get requiredSkills {
    switch (this) {
      case HarmonyRank.awakening:
        return 0;
      case HarmonyRank.bronze:
        return 2;
      case HarmonyRank.silver:
        return 4;
      case HarmonyRank.gold:
        return 6;
      case HarmonyRank.platinum:
        return 8;
      case HarmonyRank.rainbow:
        return 10;
    }
  }
}

int xpThresholdForLevel(int level) {
  const thresholds = [0, 0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700];
  if (level <= 1) return 0;
  if (level <= 10) return thresholds[level];
  return 2700 + ((level - 10) * 500);
}

int skillXpThresholdForLevel(int level) {
  if (level <= 1) return 0;
  if (level == 2) return 100;
  if (level == 3) return 300;
  if (level == 4) return 600;
  return 1000;
}
