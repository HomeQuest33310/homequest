import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/profile/domain/profile_avatar.dart';

void main() {
  test('les quatre premiers avatars premium coûtent 100 pièces d’or', () {
    final premium =
        profileAvatarCatalog.where((avatar) => avatar.isPremium).toList();

    expect(premium, hasLength(8));
    expect(premium.map((avatar) => avatar.goldPrice), everyElement(100));
    expect(
      premium.map((avatar) => avatar.key),
      [
        'akatsuki_ninja',
        'warrior_queen',
        'totoro',
        'pirate_captain',
        'violet_professor',
        'french_scout',
        'crystal_sword_guardian',
        'meerkat',
      ],
    );
    expect(premium.map((avatar) => avatar.assetPath), everyElement(isNotNull));
  });

  test('un avatar inconnu utilise l’explorateur par défaut', () {
    expect(profileAvatarFor('inconnu').key, 'explorer');
  });
}
