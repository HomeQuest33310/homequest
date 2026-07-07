class Chronicle {
  final String id;
  final String familyId;
  final String type;
  final String title;
  final String? body;
  final DateTime createdAt;

  const Chronicle({
    required this.id,
    required this.familyId,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
  });

  factory Chronicle.fromMap(Map<String, dynamic> map) {
    return Chronicle(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
