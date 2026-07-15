class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.familyId,
    required this.kingdomId,
    required this.email,
    required this.role,
    required this.membershipScope,
    required this.token,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.domainId,
    this.emailSent = false,
    this.emailError,
  });

  final String id;
  final String familyId;
  final String kingdomId;
  final String? domainId;
  final String email;
  final String role;
  final String membershipScope;
  final String token;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool emailSent;
  final String? emailError;

  factory FamilyInvitation.fromMap(Map<String, dynamic> map) {
    return FamilyInvitation(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      kingdomId: map['kingdom_id'] as String,
      domainId: map['domain_id'] as String?,
      email: map['email'] as String,
      role: map['role'] as String,
      membershipScope: map['membership_scope'] as String,
      token: map['token'] as String,
      status: map['status'] as String,
      expiresAt: DateTime.parse(map['expires_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      emailSent: map['email_sent'] as bool? ?? false,
      emailError: map['email_error'] as String?,
    );
  }
}
