import '../domain/rpg_profile.dart';

abstract class RpgProfileRepository {
  Future<RpgProfile> getMyProfile(String familyId);

  Future<RpgProfile> getMemberProfile({
    required String familyId,
    required String memberId,
  });

  Future<void> updateMyProfile({
    required String displayName,
    required String avatarKey,
  });
}
