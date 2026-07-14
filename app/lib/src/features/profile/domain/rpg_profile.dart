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
    final activeSkills = skills.where((skill) => skill.xp > 0).toList()
      ..sort((left, right) => right.xp.compareTo(left.xp));
    if (activeSkills.isNotEmpty) {
      return '${roleLabel.split(' ').first} de ${activeSkills.first.name}';
    }
    return '$roleLabel du Royaume';
  }
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
