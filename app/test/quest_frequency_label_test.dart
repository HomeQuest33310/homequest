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
}
