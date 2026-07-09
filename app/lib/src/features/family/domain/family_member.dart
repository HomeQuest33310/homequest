class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String displayName;
  final String role;

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['user_id'] as String,
      displayName: map['display_name'] as String,
      role: map['role'] as String,
    );
  }
}