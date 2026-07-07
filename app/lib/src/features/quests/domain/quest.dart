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
    );
  }
}
