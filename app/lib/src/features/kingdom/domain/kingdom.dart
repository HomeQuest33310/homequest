class Kingdom {
  const Kingdom({
    required this.id,
    required this.familyId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.isPrimary,
    this.membershipRole = 'adventurer',
    this.membershipScope = 'kingdom',
    this.membershipDomainId,
    this.membershipExpiresAt,
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
      membershipRole: map['membership_role'] as String? ?? 'adventurer',
      membershipScope: map['membership_scope'] as String? ?? 'kingdom',
      membershipDomainId: map['membership_domain_id'] as String?,
      membershipExpiresAt: map['membership_expires_at'] == null
          ? null
          : DateTime.parse(map['membership_expires_at'] as String),
    );
  }

  final String id;
  final String familyId;
  final String name;
  final String kind;
  final String icon;
  final String? description;
  final bool isPrimary;
  final String membershipRole;
  final String membershipScope;
  final String? membershipDomainId;
  final DateTime? membershipExpiresAt;
}
