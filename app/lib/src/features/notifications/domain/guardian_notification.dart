class GuardianNotification {
  const GuardianNotification({
    required this.id,
    required this.familyId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.actionRoute,
    this.actionLabel,
    this.readAt,
  });

  final String id;
  final String familyId;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? actionRoute;
  final String? actionLabel;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory GuardianNotification.fromMap(Map<String, dynamic> map) {
    return GuardianNotification(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      kind: map['kind'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      actionRoute: map['action_route'] as String?,
      actionLabel: map['action_label'] as String?,
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String),
    );
  }
}
