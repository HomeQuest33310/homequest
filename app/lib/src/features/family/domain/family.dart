class Family {
  final String id;
  final String name;
  final String kingdomName;
  final String ownerId;
  final DateTime createdAt;

  const Family({
    required this.id,
    required this.name,
    required this.kingdomName,
    required this.ownerId,
    required this.createdAt,
  });

  factory Family.fromMap(Map<String, dynamic> map) {
    return Family(
      id: map['id'] as String,
      name: map['name'] as String,
      kingdomName: map['kingdom_name'] as String,
      ownerId: map['owner_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
