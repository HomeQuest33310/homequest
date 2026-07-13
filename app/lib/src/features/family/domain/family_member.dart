class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.level,
    required this.xp,
    required this.gold,
    required this.isActive,
    this.avatarKey,
    this.membershipScope = 'kingdom',
    this.domainId,
    this.expiresAt,
  });

  /// ID de la ligne family_members.
  /// C’est cet ID qui doit être envoyé à assign_quest.
  final String id;

  /// ID de l’utilisateur / profil.
  final String userId;

  final String displayName;
  final String? avatarKey;
  final String role;
  final int level;
  final int xp;
  final int gold;
  final bool isActive;
  final String membershipScope;
  final String? domainId;
  final DateTime? expiresAt;
}
