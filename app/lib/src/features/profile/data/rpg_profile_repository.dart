import '../domain/rpg_profile.dart';

abstract class RpgProfileRepository {
  Future<RpgProfile> getMyProfile(String familyId);

  Future<void> updateMyProfile({
    required String displayName,
    required String avatarKey,
  });
}
