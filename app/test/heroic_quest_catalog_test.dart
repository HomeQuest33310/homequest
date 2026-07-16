import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/profile/domain/rpg_profile.dart';
import 'package:homequestoria/src/features/quests/domain/quest_suggestion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the heroic grimoire exposes the 90 attached quest proposals', () async {
    final suggestions = await QuestSuggestionCatalog.load();

    expect(suggestions, hasLength(90));
    expect(suggestions.every((quest) => quest.skills.length == 2), isTrue);
    expect(suggestions.map((quest) => quest.id).toSet(), hasLength(90));
    expect(suggestions.map((quest) => quest.id).toSet(),
        containsAll(List<int>.generate(90, (index) => index + 1)));
  });

  test('the latest quests keep their new heroic locations', () async {
    final suggestions = await QuestSuggestionCatalog.load();
    final byId = {for (final quest in suggestions) quest.id: quest};

    expect(byId[76]?.locationKey, 'animal_care');
    expect(byId[86]?.locationKey, 'vehicle');
    expect(byId[88]?.locationKey, 'wellbeing');
    expect(byId[90]?.locationKey, 'community');
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
