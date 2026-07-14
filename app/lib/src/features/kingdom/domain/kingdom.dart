class Kingdom {
  const Kingdom({
    required this.id,
    required this.familyId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.isPrimary,
    this.description,
  });

  factory Kingdom.fromMap(Map<String, dynamic> map) {
    return Kingdom(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      name: map['name'] as String,
      kind: map['kind'] as String,
      icon: map['icon'] as String? ?? '🏠',
      description: map['description'] as String?,
      isPrimary: map['is_primary'] as bool? ?? false,
    );
  }

  final String id;
  final String familyId;
  final String name;
  final String kind;
  final String icon;
  final String? description;
  final bool isPrimary;
}
