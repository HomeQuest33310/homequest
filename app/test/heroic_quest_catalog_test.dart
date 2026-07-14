import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/profile/domain/rpg_profile.dart';
import 'package:homequestoria/src/features/quests/domain/quest_suggestion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the heroic grimoire exposes the 75 attached quest proposals', () async {
    final suggestions = await QuestSuggestionCatalog.load();

    expect(suggestions, hasLength(75));
    expect(suggestions.every((quest) => quest.skills.length == 2), isTrue);
    expect(suggestions.map((quest) => quest.id).toSet(), hasLength(75));
  });

  test('the ten heroic skills have unique identifiers', () {
    expect(heroicSkills, hasLength(10));
    expect(heroicSkills.map((skill) => skill.id).toSet(), hasLength(10));
  });

  test('skill levels follow the progression from the grimoire', () {
    expect(skillXpThresholdForLevel(1), 0);
    expect(skillXpThresholdForLevel(2), 100);
    expect(skillXpThresholdForLevel(3), 300);
    expect(skillXpThresholdForLevel(4), 600);
    expect(skillXpThresholdForLevel(5), 1000);
  });
}
