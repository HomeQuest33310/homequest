import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/profile/domain/rpg_profile.dart';

void main() {
  test('cumule les aspects et expose les objets des boss vaincus', () {
    final profile = RpgProfile(
      memberId: 'member-1',
      userId: 'user-1',
      displayName: 'Ariane',
      role: 'adventurer',
      level: 2,
      xp: 120,
      gold: 15,
      kingdomName: 'Aurore',
      isOwner: false,
      skills: const [],
      recentAdventures: const [],
      approvedQuestCount: 0,
      bossVictories: [
        _victory(id: 'boss-1', element: 'Feu', item: 'Écaille ardente'),
        _victory(id: 'boss-2', element: 'Feu', item: 'Cœur de braise'),
        _victory(id: 'boss-3', element: 'Eau'),
      ],
    );

    expect(profile.elementalAspects.first.element, 'Feu');
    expect(profile.elementalAspects.first.count, 2);
    expect(profile.bossTrophies.map((item) => item.name), [
      'Écaille ardente',
      'Cœur de braise',
    ]);
  });
}

RpgBossVictory _victory({
  required String id,
  required String element,
  String item = '',
}) {
  return RpgBossVictory(
    id: id,
    name: 'Boss $id',
    emoji: '🐉',
    element: element,
    specialItem: item,
    xpReward: 50,
    defeatedAt: DateTime.utc(2026, 7, 14),
    participants: const [
      RpgBossParticipant(
        memberId: 'member-1',
        displayName: 'Ariane',
        role: 'adventurer',
      ),
    ],
  );
}
