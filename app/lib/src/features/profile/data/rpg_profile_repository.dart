import '../domain/rpg_profile.dart';

abstract class RpgProfileRepository {
  Future<RpgProfile> getMyProfile({
    required String familyId,
    required String kingdomId,
  });

  Future<RpgProfile> getMemberProfile({
    required String familyId,
    required String kingdomId,
    required String memberId,
  });

  Future<void> updateMyProfile({
    required String displayName,
    required String avatarKey,
  });

  Future<int> purchaseAvatar({
    required String familyId,
    required String avatarKey,
  });
}
