import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/boss/domain/boss_suggestion.dart';

void main() {
  test('the heroic bestiary contains the 11 proposed bosses', () {
    expect(bossSuggestions, hasLength(11));
    expect(bossSuggestions.map((boss) => boss.name).toSet(), hasLength(11));
  });

  test('all proposed bosses have valid gameplay values and skills', () {
    for (final boss in bossSuggestions) {
      expect(boss.maxHp, greaterThan(0));
      expect(boss.difficulty, inInclusiveRange(1, 5));
      expect(boss.skillRewards.length, inInclusiveRange(2, 6));
      expect(
        boss.skillRewards.map((reward) => reward.skillId).toSet(),
        hasLength(boss.skillRewards.length),
      );
    }
  });

  test('combat skill identifiers are unique', () {
    expect(combatSkills, hasLength(10));
    expect(combatSkills.map((skill) => skill.id).toSet(), hasLength(10));
  });
}
