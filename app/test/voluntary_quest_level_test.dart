import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/quests/providers/voluntary_quest_requests_provider.dart';

void main() {
  test('voluntary quests unlock at level 10', () {
    expect(meetsVoluntaryQuestLevel(9), isFalse);
    expect(meetsVoluntaryQuestLevel(10), isTrue);
    expect(meetsVoluntaryQuestLevel(11), isTrue);
  });
}
