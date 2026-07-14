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
      'created_at': '2026-07-14T12:00:00Z',
      'proposer': {
        'profile': {'display_name': 'Lina'},
      },
    });

    expect(suggestion.proposerName, 'Lina');
    expect(suggestion.statusLabel, 'Acceptée');
    expect(suggestion.guardianQuestCount, 7);
    expect(suggestion.guardianBossTheme, 'Dragon du Cinéma');
    expect(suggestion.isCollective, isTrue);
    expect(suggestion.isFulfilled, isTrue);
    expect(suggestion.completedQuestCount, 7);
  });
}
