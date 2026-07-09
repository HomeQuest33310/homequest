import '../domain/family.dart';
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
}
