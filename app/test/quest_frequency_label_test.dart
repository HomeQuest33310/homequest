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
}
