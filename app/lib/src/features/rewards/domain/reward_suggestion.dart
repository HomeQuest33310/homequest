class RewardSuggestion {
  const RewardSuggestion({
    required this.id,
    required this.proposerName,
    required this.title,
    required this.description,
    required this.suggestedQuestCount,
    required this.status,
    required this.createdAt,
    this.createdByGuardian = false,
    this.guardianTitle,
    this.guardianDescription,
    this.guardianQuestCount,
    this.guardianBossTheme,
    this.bossId,
    this.completedQuestCount = 0,
    this.fulfilledAt,
  });

  factory RewardSuggestion.fromMap(Map<String, dynamic> map) {
    final proposer = Map<String, dynamic>.from(map['proposer'] as Map);
    final profile = Map<String, dynamic>.from(proposer['profile'] as Map);
    return RewardSuggestion(
      id: map['id'] as String,
      proposerName: profile['display_name'] as String? ?? 'Aventurier',
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      suggestedQuestCount: (map['suggested_quest_count'] as num).toInt(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      createdByGuardian: map['created_by_guardian'] as bool? ?? false,
      guardianTitle: map['guardian_title'] as String?,
      guardianDescription: map['guardian_description'] as String?,
      guardianQuestCount: (map['guardian_quest_count'] as num?)?.toInt(),
      guardianBossTheme: map['guardian_boss_theme'] as String?,
      bossId: map['boss_id'] as String?,
      completedQuestCount: (map['completed_quest_count'] as num?)?.toInt() ?? 0,
      fulfilledAt: map['fulfilled_at'] == null
          ? null
          : DateTime.parse(map['fulfilled_at'] as String),
    );
  }

  final String id;
  final String proposerName;
  final String title;
  final String description;
  final int suggestedQuestCount;
  final String status;
  final DateTime createdAt;
  final bool createdByGuardian;
  final String? guardianTitle;
  final String? guardianDescription;
  final int? guardianQuestCount;
  final String? guardianBossTheme;
  final String? bossId;
  final int completedQuestCount;
  final DateTime? fulfilledAt;

  bool get isCollective => status == 'approved';
  bool get isFulfilled => fulfilledAt != null;

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Acceptée';
      case 'rejected':
        return 'Refusée';
      default:
        return 'En attente';
    }
  }
}
