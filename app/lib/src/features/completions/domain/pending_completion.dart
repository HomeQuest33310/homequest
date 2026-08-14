class PendingCompletion {
  const PendingCompletion({
    required this.id,
    required this.questId,
    required this.questTitle,
    required this.realTask,
    required this.completedBy,
    required this.displayName,
    required this.frequency,
    required this.assignedMembers,
    required this.completedAt,
    required this.xpReward,
    required this.goldReward,
    required this.bossDamage,
    this.note,
    this.photoUrl,
  });

  final String id;
  final String questId;
  final String questTitle;
  final String realTask;
  final String completedBy;
  final String displayName;
  final String frequency;
  final List<CompletionParticipant> assignedMembers;
  final DateTime completedAt;
  final int xpReward;
  final int goldReward;
  final int bossDamage;
  final String? note;
  final String? photoUrl;

  factory PendingCompletion.fromMap(Map<String, dynamic> map) {
    return PendingCompletion(
      id: map['id'] as String,
      questId: map['quest_id'] as String,
      questTitle: map['quest_title'] as String,
      realTask: map['real_task'] as String,
      completedBy: map['completed_by'] as String,
      displayName: map['display_name'] as String,
      frequency: map['frequency'] as String? ?? 'once',
      assignedMembers: (map['assigned_members'] as List? ?? const [])
          .map((item) => CompletionParticipant.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      completedAt: DateTime.parse(map['completed_at'] as String),
      xpReward: map['xp_reward'] as int,
      goldReward: map['gold_reward'] as int,
      bossDamage: map['boss_damage'] as int,
      note: map['note'] as String?,
      photoUrl: map['photo_url'] as String?,
    );
  }
}

class CompletionParticipant {
  const CompletionParticipant({required this.memberId, required this.displayName});

  final String memberId;
  final String displayName;

  factory CompletionParticipant.fromMap(Map<String, dynamic> map) {
    return CompletionParticipant(
      memberId: map['member_id'] as String,
      displayName: map['display_name'] as String? ?? 'Utilisateur inconnu',
    );
  }
}

class CompletionReward {
  const CompletionReward({
    required this.xp,
    required this.gold,
    required this.bossDamage,
    required this.level,
    required this.bossDefeated,
    this.participantsCount = 1,
  });

  final int xp;
  final int gold;
  final int bossDamage;
  final int level;
  final bool bossDefeated;
  final int participantsCount;

  factory CompletionReward.fromMap(Map<String, dynamic> map) {
    return CompletionReward(
      xp: map['xp_reward'] as int? ?? 0,
      gold: map['gold_reward'] as int? ?? 0,
      bossDamage: map['boss_damage'] as int? ?? 0,
      level: map['new_level'] as int? ?? 1,
      bossDefeated: map['boss_defeated'] as bool? ?? false,
      participantsCount: (map['participants_count'] as num?)?.toInt() ?? 1,
    );
  }
}
