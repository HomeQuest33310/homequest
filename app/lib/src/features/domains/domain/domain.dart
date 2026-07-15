class Domain {
  final String id;
  final String familyId;
  final String kingdomId;
  final String name;
  final String domainKind;
  final String icon;
  final String? description;
  final bool isPrimary;
  final DateTime createdAt;

  const Domain({
    required this.id,
    required this.familyId,
    required this.kingdomId,
    required this.name,
    required this.domainKind,
    required this.icon,
    required this.isPrimary,
    required this.createdAt,
    this.description,
  });

  factory Domain.fromMap(Map<String, dynamic> map) {
    return Domain(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      kingdomId: map['kingdom_id'] as String,
      name: map['name'] as String,
      domainKind: map['domain_kind'] as String,
      icon: map['icon'] as String,
      description: map['description'] as String?,
      isPrimary: map['is_primary'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
