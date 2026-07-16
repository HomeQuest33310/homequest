import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/profile/domain/profile_avatar.dart';

void main() {
  test('les quatre premiers avatars premium coûtent 100 pièces d’or', () {
    final premium =
        profileAvatarCatalog.where((avatar) => avatar.isPremium).toList();

    expect(premium, hasLength(4));
    expect(premium.map((avatar) => avatar.goldPrice), everyElement(100));
    expect(
      premium.map((avatar) => avatar.key),
      ['akatsuki_ninja', 'warrior_queen', 'totoro', 'meerkat'],
    );
    expect(premium.map((avatar) => avatar.assetPath), everyElement(isNotNull));
  });

  test('un avatar inconnu utilise l’explorateur par défaut', () {
    expect(profileAvatarFor('inconnu').key, 'explorer');
  });
}
