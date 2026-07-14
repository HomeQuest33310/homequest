import 'boss.dart';

class CombatSkill {
  const CombatSkill({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final String icon;
}

const combatSkills = <CombatSkill>[
  CombatSkill(id: 'combat', name: 'Art de la Lame', icon: '⚔️'),
  CombatSkill(id: 'defense', name: 'Rempart d’Adamant', icon: '🛡️'),
  CombatSkill(id: 'precision', name: 'Œil du Faucon', icon: '🎯'),
  CombatSkill(id: 'cooperation', name: 'Serment de la Guilde', icon: '👥'),
  CombatSkill(
    id: 'elemental_mastery',
    name: 'Souveraineté Élémentaire',
    icon: '🔥',
  ),
  CombatSkill(id: 'resilience', name: 'Cœur Inébranlable', icon: '⏳'),
  CombatSkill(id: 'power', name: 'Fureur du Colosse', icon: '💪'),
  CombatSkill(id: 'combat_agility', name: 'Danse du Zéphyr', icon: '🏃'),
  CombatSkill(id: 'tactics', name: 'Stratagème Royal', icon: '🧠'),
  CombatSkill(id: 'magic_mastery', name: 'Arcane Suprême', icon: '✨'),
];

class BossSuggestion {
  const BossSuggestion({
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.element,
    required this.domainLabel,
    required this.description,
    required this.maxHp,
    required this.difficulty,
    required this.requiredLevel,
    required this.xpReward,
    required this.specialItem,
    required this.skillRewards,
  });

  final String name;
  final String emoji;
  final String subtitle;
  final String element;
  final String domainLabel;
  final String description;
  final int maxHp;
  final int difficulty;
  final int requiredLevel;
  final int xpReward;
  final String specialItem;
  final List<BossSkillReward> skillRewards;

  String get fullName => '$name — $subtitle';
}

BossSkillReward _reward(String id, int points) {
  final skill = combatSkills.firstWhere((item) => item.id == id);
  return BossSkillReward(
    skillId: skill.id,
    name: skill.name,
    icon: skill.icon,
    points: points,
  );
}

final bossSuggestions = <BossSuggestion>[
  BossSuggestion(
    name: 'INFERNO',
    emoji: '🔥',
    subtitle: 'Le Seigneur des Flammes',
    element: 'Feu',
    domainLabel: 'Château',
    maxHp: 500,
    difficulty: 3,
    requiredLevel: 5,
    xpReward: 2500,
    specialItem: '🔥 Couronne de Flamme',
    description:
        'Un géant de lave couronné de feu dont le rugissement fait trembler le royaume.',
    skillRewards: [
      _reward('power', 50),
      _reward('combat', 40),
      _reward('elemental_mastery', 60)
    ],
  ),
  BossSuggestion(
    name: 'TYPHOON',
    emoji: '💧',
    subtitle: 'Le Maître des Eaux',
    element: 'Eau',
    domainLabel: 'Côte',
    maxHp: 480,
    difficulty: 3,
    requiredLevel: 5,
    xpReward: 2500,
    specialItem: '💧 Trident Aquatique',
    description:
        'Un colosse d’eau cristalline capable de déchaîner vagues et tempêtes.',
    skillRewards: [
      _reward('combat_agility', 45),
      _reward('resilience', 40),
      _reward('elemental_mastery', 65)
    ],
  ),
  BossSuggestion(
    name: 'STONEHEART',
    emoji: '🌍',
    subtitle: 'Le Titan de Pierre',
    element: 'Terre',
    domainLabel: 'Montagne',
    maxHp: 550,
    difficulty: 3,
    requiredLevel: 5,
    xpReward: 2500,
    specialItem: '🌍 Gemme de Terre',
    description:
        'Un géant de roche vivante, lent mais doté d’une puissance écrasante.',
    skillRewards: [
      _reward('defense', 55),
      _reward('power', 50),
      _reward('elemental_mastery', 60)
    ],
  ),
  BossSuggestion(
    name: 'STORMWIND',
    emoji: '💨',
    subtitle: 'Le Maître des Tempêtes',
    element: 'Air',
    domainLabel: 'Forêt',
    maxHp: 450,
    difficulty: 3,
    requiredLevel: 5,
    xpReward: 2500,
    specialItem: '💨 Cape du Vent',
    description: 'Une incarnation insaisissable des vents et des tempêtes.',
    skillRewards: [
      _reward('combat_agility', 60),
      _reward('precision', 45),
      _reward('elemental_mastery', 55)
    ],
  ),
  BossSuggestion(
    name: 'LUMINAR',
    emoji: '✨',
    subtitle: 'Le Gardien de la Lumière',
    element: 'Lumière',
    domainLabel: 'Temple',
    maxHp: 480,
    difficulty: 3,
    requiredLevel: 5,
    xpReward: 2500,
    specialItem: '✨ Orbe de Lumière',
    description:
        'Un gardien sacré dont les rayons frappent avec une précision parfaite.',
    skillRewards: [
      _reward('magic_mastery', 70),
      _reward('precision', 50),
      _reward('combat', 40)
    ],
  ),
  BossSuggestion(
    name: 'MECHANOMANCER',
    emoji: '⚙️',
    subtitle: 'Le Seigneur des Machines',
    element: 'Métal et Électricité',
    domainLabel: 'Forge mécanique',
    maxHp: 600,
    difficulty: 4,
    requiredLevel: 10,
    xpReward: 4000,
    specialItem: '⚙️ Cœur Mécanique',
    description:
        'Un cyborg colossal entouré d’engrenages et d’éclairs destructeurs.',
    skillRewards: [
      _reward('tactics', 70),
      _reward('combat', 55),
      _reward('elemental_mastery', 75)
    ],
  ),
  BossSuggestion(
    name: 'NATURALIS',
    emoji: '🌿',
    subtitle: 'Le Roi de la Jungle',
    element: 'Nature',
    domainLabel: 'Forêt profonde',
    maxHp: 580,
    difficulty: 4,
    requiredLevel: 10,
    xpReward: 4000,
    specialItem: '🌿 Couronne de Vigne',
    description:
        'Une force ancienne de la jungle capable de se régénérer sans fin.',
    skillRewards: [
      _reward('power', 65),
      _reward('elemental_mastery', 85),
      _reward('resilience', 50)
    ],
  ),
  BossSuggestion(
    name: 'SHADOWBORN',
    emoji: '🌑',
    subtitle: 'Le Maître des Ténèbres',
    element: 'Ombre',
    domainLabel: 'Caverne obscure',
    maxHp: 620,
    difficulty: 4,
    requiredLevel: 10,
    xpReward: 4000,
    specialItem: '🌑 Manteau d’Ombre',
    description:
        'Une présence furtive qui se dissout dans les ombres avant de frapper.',
    skillRewards: [
      _reward('combat_agility', 75),
      _reward('defense', 60),
      _reward('elemental_mastery', 80)
    ],
  ),
  BossSuggestion(
    name: 'TEMPESTIX',
    emoji: '⚡',
    subtitle: 'Le Seigneur de la Foudre',
    element: 'Électricité',
    domainLabel: 'Pic des Tempêtes',
    maxHp: 700,
    difficulty: 5,
    requiredLevel: 15,
    xpReward: 6000,
    specialItem: '⚡ Trident de Foudre',
    description:
        'Un titan de foudre pure dont chaque geste provoque une décharge dévastatrice.',
    skillRewards: [
      _reward('power', 80),
      _reward('elemental_mastery', 100),
      _reward('cooperation', 70)
    ],
  ),
  BossSuggestion(
    name: 'FROSTKING',
    emoji: '❄️',
    subtitle: 'Le Roi de la Glace',
    element: 'Glace',
    domainLabel: 'Sommet gelé',
    maxHp: 680,
    difficulty: 5,
    requiredLevel: 15,
    xpReward: 6000,
    specialItem: '❄️ Couronne de Glace',
    description: 'Un roi cuirassé de glace, presque impossible à ébranler.',
    skillRewards: [
      _reward('defense', 85),
      _reward('elemental_mastery', 95),
      _reward('resilience', 75)
    ],
  ),
  BossSuggestion(
    name: 'CHAOSDRAKUL',
    emoji: '🌀',
    subtitle: 'Le Dragon du Chaos',
    element: 'Tous les éléments',
    domainLabel: 'Ruines antiques',
    maxHp: 1000,
    difficulty: 5,
    requiredLevel: 20,
    xpReward: 10000,
    specialItem: '🐉 Cœur de Dragon',
    description:
        'Le dragon ultime. Son corps change d’élément et seule une guilde unie peut le vaincre.',
    skillRewards: [
      _reward('cooperation', 150),
      _reward('combat', 120),
      _reward('elemental_mastery', 200),
      _reward('tactics', 100),
      _reward('magic_mastery', 150),
      _reward('precision', 80)
    ],
  ),
];
