import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/kingdom/domain/kingdom_construction.dart';
import 'package:homequestoria/src/features/kingdom/domain/kingdom_resources.dart';

void main() {
  KingdomConstruction construction({
    int wood = 0,
    int stone = 0,
    int provisions = 0,
    int crystals = 0,
    int bossItems = 0,
    int tierThreeItems = 0,
  }) {
    return KingdomConstruction(
      key: 'celestial_tower',
      name: 'Tour Céleste',
      emoji: '🌌',
      category: 'legendary',
      tier: 3,
      description: 'Description',
      bonusDescription: 'Bonus',
      woodCost: wood,
      stoneCost: stone,
      provisionsCost: provisions,
      crystalsCost: crystals,
      bossItemsCost: bossItems,
      tierThreeItemsCost: tierThreeItems,
      buildHours: 72,
      maxLevel: 5,
      level: 0,
      targetLevel: 1,
      status: 'available',
    );
  }

  const resources = KingdomResources(
    wood: 2000,
    stone: 2500,
    provisions: 500,
    crystals: 50,
    bossItems: [
      KingdomBossItem(
        key: 'dragon_heart',
        name: 'Cœur de Dragon',
        emoji: '🐉',
        tier: 3,
        quantity: 5,
      ),
      KingdomBossItem(
        key: 'flame_crown',
        name: 'Couronne de Flammes',
        emoji: '🔥',
        tier: 1,
        quantity: 5,
      ),
    ],
  );

  test('accepte le coût exact de la Tour Céleste', () {
    final tower = construction(
      wood: 2000,
      stone: 2500,
      crystals: 50,
      bossItems: 10,
      tierThreeItems: 5,
    );

    expect(tower.canAfford(resources), isTrue);
  });

  test('refuse une construction sans assez d’objets de boss niveau 3', () {
    final tower = construction(bossItems: 10, tierThreeItems: 6);

    expect(tower.canAfford(resources), isFalse);
  });

  test('refuse une construction si une ressource collective manque', () {
    final tower = construction(wood: 2001);

    expect(tower.canAfford(resources), isFalse);
  });
}
