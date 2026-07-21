class Quest {
  const Quest({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.title,
    required this.realTask,
    required this.xpReward,
    required this.goldReward,
    required this.bossDamage,
    required this.frequency,
    required this.requiresApproval,
    required this.status,
    required this.createdAt,
    this.description,
    this.availableFrom,
    this.recurrenceWeekday,
    this.regionKey,
    this.domainId,
    this.emoji = '📜',
    this.element = 'Neutre',
    this.difficulty = 1,
    this.skillRewards = const [],
    this.assignees = const [],
  });

  final String id;
  final String familyId;
  final String createdBy;
  final String title;
  final String realTask;
  final String? description;
  final DateTime? availableFrom;
  /// ISO weekday (1 = Monday … 7 = Sunday) for weekly quests.
  final int? recurrenceWeekday;
  final String? regionKey;
  final String? domainId;
  final String emoji;
  final String element;
  final int difficulty;
  final int xpReward;
  final int goldReward;
  final int bossDamage;
  final String frequency;

  String get frequencyLabel => switch (frequency) {
        'once' => 'Une seule fois',
        'daily' => 'Quotidien',
        'weekly' => 'Hebdomadaire',
        _ => frequency,
      };

  bool isAvailableAt(DateTime moment) =>
      availableFrom == null || !moment.isBefore(availableFrom!);

  bool get isAvailableNow => isAvailableAt(DateTime.now());

  final bool requiresApproval;
  final String status;
  final DateTime createdAt;
  final List<QuestSkillReward> skillRewards;
  final List<QuestAssignee> assignees;

  factory Quest.fromMap(Map<String, dynamic> map) {
    return Quest(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      createdBy: map['created_by'] as String,
      title: map['title'] as String,
      realTask: map['real_task'] as String,
      description: map['description'] as String?,
      availableFrom: map['available_from'] == null
          ? null
          : DateTime.parse(map['available_from'] as String),
      recurrenceWeekday: (map['recurrence_weekday'] as num?)?.toInt(),
      regionKey: map['region_key'] as String?,
      domainId: map['domain_id'] as String?,
      emoji: map['emoji'] as String? ?? '📜',
      element: map['element'] as String? ?? 'Neutre',
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
      xpReward: map['xp_reward'] as int,
      goldReward: map['gold_reward'] as int,
      bossDamage: map['boss_damage'] as int,
      frequency: map['frequency'] as String,
      requiresApproval: map['requires_approval'] as bool,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      skillRewards: (map['skill_rewards'] as List? ?? const [])
          .map(
            (item) => QuestSkillReward.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      assignees: (map['assignees'] as List? ?? const [])
          .map(
            (item) => QuestAssignee.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class QuestSkillReward {
  const QuestSkillReward({
    required this.skillId,
    required this.name,
    required this.icon,
    required this.xpReward,
  });

  final String skillId;
  final String name;
  final String icon;
  final int xpReward;

  factory QuestSkillReward.fromMap(Map<String, dynamic> map) {
    return QuestSkillReward(
      skillId: map['skill_id'] as String,
      name: map['name'] as String? ?? map['skill_id'] as String,
      icon: map['icon'] as String? ?? '✨',
      xpReward: (map['xp_reward'] as num).toInt(),
    );
  }

  Map<String, dynamic> toRpcMap() => {
        'skill_id': skillId,
        'xp_reward': xpReward,
      };
}

class QuestAssignee {
  const QuestAssignee({
    required this.memberId,
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String memberId;
  final String userId;
  final String displayName;
  final String role;

  factory QuestAssignee.fromMap(Map<String, dynamic> map) {
    return QuestAssignee(
      memberId: map['member_id'] as String,
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String,
      role: map['role'] as String,
    );
  }
}
