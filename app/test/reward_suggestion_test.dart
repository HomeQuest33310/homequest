import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/rewards/domain/reward_suggestion.dart';

void main() {
  test('lit une suggestion approuvée par un Gardien', () {
    final suggestion = RewardSuggestion.fromMap({
      'id': 'suggestion-1',
      'title': 'Choisir le film',
      'description': 'Pour la soirée familiale',
      'suggested_quest_count': 5,
      'status': 'approved',
      'guardian_title': 'Choisir le film du samedi',
      'guardian_description': 'Après le défi',
      'guardian_quest_count': 7,
      'guardian_boss_theme': 'Dragon du Cinéma',
      'boss_id': 'boss-1',
      'completed_quest_count': 7,
      'fulfilled_at': '2026-07-15T12:00:00Z',
      'created_by_guardian': true,
      'created_at': '2026-07-14T12:00:00Z',
      'proposer': {
        'profile': {'display_name': 'Lina'},
      },
    });

    expect(suggestion.proposerName, 'Lina');
    expect(suggestion.statusLabel, 'Débloquée');
    expect(suggestion.guardianQuestCount, 7);
    expect(suggestion.guardianBossTheme, 'Dragon du Cinéma');
    expect(suggestion.isCollective, isTrue);
    expect(suggestion.isFulfilled, isTrue);
    expect(suggestion.completedQuestCount, 7);
    expect(suggestion.createdByGuardian, isTrue);
  });

  test('distingue une récompense acceptée, débloquée, remise ou archivée', () {
    RewardSuggestion suggestion({
      DateTime? fulfilledAt,
      DateTime? deliveredAt,
      DateTime? archivedAt,
    }) =>
        RewardSuggestion(
          id: 'reward',
          proposerName: 'Lina',
          title: 'Soirée cinéma',
          description: '',
          suggestedQuestCount: 5,
          status: 'approved',
          createdAt: DateTime.utc(2026),
          guardianQuestCount: 5,
          fulfilledAt: fulfilledAt,
          deliveredAt: deliveredAt,
          archivedAt: archivedAt,
        );

    expect(suggestion().statusLabel, 'Acceptée');
    expect(
      suggestion(fulfilledAt: DateTime.utc(2026, 7, 17)).statusLabel,
      'Débloquée',
    );
    expect(
      suggestion(
        fulfilledAt: DateTime.utc(2026, 7, 17),
        deliveredAt: DateTime.utc(2026, 7, 18),
      ).statusLabel,
      'Remise',
    );
    expect(
      suggestion(archivedAt: DateTime.utc(2026, 7, 18)).statusLabel,
      'Archivée',
    );
  });

  test('ne garde dans la priorité que les objectifs approuvés et inachevés',
      () {
    RewardSuggestion suggestion({
      String status = 'approved',
      int completed = 2,
      int? target = 5,
      DateTime? archivedAt,
    }) =>
        RewardSuggestion(
          id: 'reward',
          proposerName: 'Lina',
          title: 'Soirée cinéma',
          description: '',
          suggestedQuestCount: 5,
          status: status,
          createdAt: DateTime.utc(2026),
          guardianQuestCount: target,
          completedQuestCount: completed,
          archivedAt: archivedAt,
        );

    expect(suggestion().isInQuestPriorityQueue, isTrue);
    expect(suggestion(completed: 5).isInQuestPriorityQueue, isFalse);
    expect(suggestion(status: 'pending').isInQuestPriorityQueue, isFalse);
    expect(suggestion(target: null).isInQuestPriorityQueue, isFalse);
    expect(
      suggestion(archivedAt: DateTime.utc(2026, 7, 18)).isInQuestPriorityQueue,
      isFalse,
    );
  });
}
