class SkillProgress {
  const SkillProgress({
    required this.name,
    required this.icon,
    required this.xp,
    required this.level,
  });

  final String name;
  final String icon;
  final int xp;
  final int level;
}

enum HarmonyRank { bronze, silver, gold, platinum, rainbow }

HarmonyRank harmonyRankFor(List<SkillProgress> skills) {
  final activeSkills = skills.where((skill) => skill.xp > 0).length;
  if (activeSkills >= 10) return HarmonyRank.rainbow;
  if (activeSkills >= 8) return HarmonyRank.platinum;
  if (activeSkills >= 6) return HarmonyRank.gold;
  if (activeSkills >= 4) return HarmonyRank.silver;
  return HarmonyRank.bronze;
}

String harmonyLabel(HarmonyRank rank) {
  switch (rank) {
    case HarmonyRank.bronze: return 'Harmonie bronze';
    case HarmonyRank.silver: return 'Harmonie argent';
    case HarmonyRank.gold: return 'Harmonie or';
    case HarmonyRank.platinum: return 'Harmonie platine';
    case HarmonyRank.rainbow: return 'Harmonie arc-en-ciel';
  }
}
