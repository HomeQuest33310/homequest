import '../domain/family.dart';
import '../domain/family_invitation.dart';
import '../domain/family_member.dart';

abstract class FamilyRepository {
  Future<Family> createFamily({
    required String familyName,
    required String kingdomName,
    required String primaryDomainName,
    required String ownerId,
  });

  Future<Family?> getCurrentUserFamily(String userId);

  Future<List<FamilyMember>> getMembers(String familyId);

  Future<FamilyMember> changeMemberRole({
    required String memberId,
    required String newRole,
  });

  Future<FamilyMember> deactivateMember(String memberId);

  Future<List<FamilyInvitation>> getInvitations(String familyId);

  Future<FamilyInvitation> inviteMember({
    required String familyId,
    required String email,
    required String role,
    required String membershipScope,
    String? domainId,
    int expiresInDays = 7,
  });

  Future<void> cancelInvitation(String invitationId);

  Future<void> acceptInvitation(String token);
}
