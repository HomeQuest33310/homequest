import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/family/providers/family_stats_provider.dart';
import 'package:homequestoria/src/features/kingdom/domain/kingdom_progress.dart';

void main() {
  const stats = FamilyStats(
    memberCount: 4,
    domainCount: 1,
    chronicleCount: 1,
    approvedQuestCount: 60,
    defeatedBossCount: 0,
    deliveredRewardCount: 0,
  );

  test('tous les bâtiments d’évolution dépendent des quêtes', () {
    final progress = KingdomProgress.fromStats(stats);

    expect(
      progress.buildings.every(
        (building) => building.goal == KingdomBuildingGoal.quests,
      ),
      isTrue,
    );
  });

  test('les bâtiments se débloquent automatiquement aux bons seuils', () {
    final progress = KingdomProgress.fromStats(stats);

    expect(progress.unlockedBuildingCount, 5);
    expect(
      progress.buildings
          .firstWhere((building) => building.name == 'Hall des Trophées')
          .isUnlocked,
      isTrue,
    );
    expect(
      progress.buildings
          .firstWhere((building) => building.name == 'Jardin des Souhaits')
          .isUnlocked,
      isFalse,
    );
  });
}
