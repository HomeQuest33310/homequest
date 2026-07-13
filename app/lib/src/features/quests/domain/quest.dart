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
    this.regionKey,
    this.domainId,
    this.assignees = const [],
  });

  final String id;
  final String familyId;
  final String createdBy;
  final String title;
  final String realTask;
  final String? description;
  final String? regionKey;
  final String? domainId;
  final int xpReward;
  final int goldReward;
  final int bossDamage;
  final String frequency;
  final bool requiresApproval;
  final String status;
  final DateTime createdAt;
  final List<QuestAssignee> assignees;

  factory Quest.fromMap(Map<String, dynamic> map) {
    return Quest(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      createdBy: map['created_by'] as String,
      title: map['title'] as String,
      realTask: map['real_task'] as String,
      description: map['description'] as String?,
      regionKey: map['region_key'] as String?,
      domainId: map['domain_id'] as String?,
      xpReward: map['xp_reward'] as int,
      goldReward: map['gold_reward'] as int,
      bossDamage: map['boss_damage'] as int,
      frequency: map['frequency'] as String,
      requiresApproval: map['requires_approval'] as bool,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
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
