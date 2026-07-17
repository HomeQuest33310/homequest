import '../../quests/domain/quest.dart';

class MissionCompletion {
  const MissionCompletion({
    required this.id,
    required this.status,
    required this.completedAt,
    this.note,
    this.rejectionReason,
  });

  final String id;
  final String status;
  final DateTime completedAt;
  final String? note;
  final String? rejectionReason;

  factory MissionCompletion.fromMap(Map<String, dynamic> map) {
    return MissionCompletion(
      id: map['id'] as String,
      status: map['status'] as String,
      completedAt: DateTime.parse(map['completed_at'] as String),
      note: map['note'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}

class MissionAssignment {
  const MissionAssignment({
    required this.assignmentId,
    required this.assignedAt,
    required this.quest,
    required this.isAvailableNow,
    this.completion,
  });

  final String assignmentId;
  final DateTime assignedAt;
  final Quest quest;
  final bool isAvailableNow;
  final MissionCompletion? completion;

  factory MissionAssignment.fromMap(Map<String, dynamic> map) {
    final completion = map['completion'];
    return MissionAssignment(
      assignmentId: map['assignment_id'] as String,
      assignedAt: DateTime.parse(map['assigned_at'] as String),
      quest: Quest.fromMap(Map<String, dynamic>.from(map['quest'] as Map)),
      isAvailableNow: map['is_available_now'] as bool? ?? true,
      completion: completion == null
          ? null
          : MissionCompletion.fromMap(
              Map<String, dynamic>.from(completion as Map),
            ),
    );
  }
}
