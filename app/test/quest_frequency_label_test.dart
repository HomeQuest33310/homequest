import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/quests/domain/quest.dart';

void main() {
  Quest questWithFrequency(String frequency) => Quest(
        id: 'quest-id',
        familyId: 'family-id',
        createdBy: 'member-id',
        title: 'Test',
        realTask: 'Tester',
        xpReward: 10,
        goldReward: 5,
        bossDamage: 1,
        frequency: frequency,
        requiresApproval: true,
        status: 'active',
        createdAt: DateTime(2026),
      );

  test('quest frequency labels are displayed in French', () {
    expect(questWithFrequency('once').frequencyLabel, 'Une seule fois');
    expect(questWithFrequency('daily').frequencyLabel, 'Quotidien');
    expect(questWithFrequency('weekly').frequencyLabel, 'Hebdomadaire');
  });

  test('unknown quest frequency remains readable', () {
    expect(questWithFrequency('custom').frequencyLabel, 'custom');
  });

  test('scheduled quest becomes available at the configured instant', () {
    final availableFrom = DateTime.utc(2026, 7, 16, 18, 30);
    final quest = Quest(
      id: 'scheduled-quest',
      familyId: 'family-id',
      createdBy: 'member-id',
      title: 'Test',
      realTask: 'Tester',
      xpReward: 10,
      goldReward: 5,
      bossDamage: 1,
      frequency: 'once',
      requiresApproval: true,
      status: 'active',
      createdAt: DateTime.utc(2026),
      availableFrom: availableFrom,
    );

    expect(
      quest.isAvailableAt(availableFrom.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    expect(quest.isAvailableAt(availableFrom), isTrue);
    expect(
      quest.isAvailableAt(availableFrom.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  test('quest mapping preserves availability, skills and assignees', () {
    final quest = Quest.fromMap({
      'id': 'quest-id',
      'family_id': 'family-id',
      'created_by': 'guardian-id',
      'title': 'Préparer le repas',
      'real_task': 'Cuisiner',
      'available_from': '2026-07-17T18:30:00Z',
      'xp_reward': 20,
      'gold_reward': 10,
      'boss_damage': 3,
      'frequency': 'weekly',
      'requires_approval': true,
      'status': 'active',
      'created_at': '2026-07-17T12:00:00Z',
      'skill_rewards': [
        {
          'skill_id': 'cuisine',
          'name': 'Cuisine',
          'icon': '🍳',
          'xp_reward': 4,
        },
      ],
      'assignees': [
        {
          'member_id': 'member-id',
          'user_id': 'user-id',
          'display_name': 'Lina',
          'role': 'adventurer',
        },
      ],
    });

    expect(quest.frequencyLabel, 'Hebdomadaire');
    expect(quest.availableFrom, DateTime.utc(2026, 7, 17, 18, 30));
    expect(quest.skillRewards.single.skillId, 'cuisine');
    expect(quest.skillRewards.single.xpReward, 4);
    expect(quest.assignees.single.displayName, 'Lina');
    expect(quest.assignees.single.role, 'adventurer');
  });
}
