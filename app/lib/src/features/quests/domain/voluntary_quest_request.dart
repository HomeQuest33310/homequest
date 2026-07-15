class VoluntaryQuestRequest {
  const VoluntaryQuestRequest({
    required this.id,
    required this.kingdomId,
    required this.domainId,
    required this.requestedBy,
    required this.requesterName,
    required this.catalogId,
    required this.title,
    required this.realTask,
    required this.emoji,
    required this.element,
    required this.difficulty,
    required this.xpReward,
    required this.goldReward,
    required this.bossDamage,
    required this.alreadyCompleted,
    required this.status,
    required this.createdAt,
    this.requesterNote,
    this.reviewNote,
    this.questId,
  });

  factory VoluntaryQuestRequest.fromMap(Map<String, dynamic> map) {
    return VoluntaryQuestRequest(
      id: map['id'] as String,
      kingdomId: map['kingdom_id'] as String,
      domainId: map['domain_id'] as String,
      requestedBy: map['requested_by'] as String,
      requesterName: map['requester_name'] as String,
      catalogId: (map['catalog_id'] as num).toInt(),
      title: map['title'] as String,
      realTask: map['real_task'] as String,
      emoji: map['emoji'] as String,
      element: map['element'] as String,
      difficulty: (map['difficulty'] as num).toInt(),
      xpReward: (map['xp_reward'] as num).toInt(),
      goldReward: (map['gold_reward'] as num).toInt(),
      bossDamage: (map['boss_damage'] as num).toInt(),
      alreadyCompleted: map['already_completed'] as bool? ?? false,
      status: map['status'] as String,
      requesterNote: map['requester_note'] as String?,
      reviewNote: map['review_note'] as String?,
      questId: map['quest_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String kingdomId;
  final String domainId;
  final String requestedBy;
  final String requesterName;
  final int catalogId;
  final String title;
  final String realTask;
  final String emoji;
  final String element;
  final int difficulty;
  final int xpReward;
  final int goldReward;
  final int bossDamage;
  final bool alreadyCompleted;
  final String status;
  final String? requesterNote;
  final String? reviewNote;
  final String? questId;
  final DateTime createdAt;
}
