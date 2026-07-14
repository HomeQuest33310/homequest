class Boss {
  const Boss({
    required this.id,
    required this.familyId,
    required this.name,
    required this.emoji,
    required this.element,
    required this.domainLabel,
    required this.description,
    required this.maxHp,
    required this.currentHp,
    required this.difficulty,
    required this.requiredLevel,
    required this.xpReward,
    required this.specialItem,
    required this.status,
    required this.skillRewards,
    required this.createdAt,
  });

  factory Boss.fromMap(Map<String, dynamic> map) {
    return Boss(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String? ?? '🐉',
      element: map['element'] as String? ?? 'Neutre',
      domainLabel: map['domain_label'] as String? ?? 'Royaume',
      description: map['description'] as String? ?? '',
      maxHp: (map['max_hp'] as num).toInt(),
      currentHp: (map['current_hp'] as num).toInt(),
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 3,
      requiredLevel: (map['required_level'] as num?)?.toInt() ?? 1,
      xpReward: (map['xp_reward'] as num?)?.toInt() ?? 0,
      specialItem: map['special_item'] as String? ?? '',
      status: map['status'] as String,
      skillRewards: (map['skill_rewards'] as List? ?? const [])
          .map(
            (item) => BossSkillReward.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String familyId;
  final String name;
  final String emoji;
  final String element;
  final String domainLabel;
  final String description;
  final int maxHp;
  final int currentHp;
  final int difficulty;
  final int requiredLevel;
  final int xpReward;
  final String specialItem;
  final String status;
  final List<BossSkillReward> skillRewards;
  final DateTime createdAt;

  double get healthProgress => maxHp <= 0 ? 0 : currentHp / maxHp;
  bool get isActive => status == 'active';
}

class BossSkillReward {
  const BossSkillReward({
    required this.skillId,
    required this.name,
    required this.icon,
    required this.points,
  });

  factory BossSkillReward.fromMap(Map<String, dynamic> map) {
    return BossSkillReward(
      skillId: map['skill_id'] as String,
      name: map['name'] as String? ?? map['skill_id'] as String,
      icon: map['icon'] as String? ?? '⚔️',
      points: (map['points'] as num).toInt(),
    );
  }

  final String skillId;
  final String name;
  final String icon;
  final int points;

  Map<String, dynamic> toRpcMap() => {
        'skill_id': skillId,
        'points': points,
      };
}
