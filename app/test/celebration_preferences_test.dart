import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/celebrations/data/celebration_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mémorise les célébrations par utilisateur et par royaume', () async {
    SharedPreferences.setMockInitialValues({});

    await CelebrationPreferences.markSeen(
      userId: 'user-1',
      familyId: 'family-1',
      eventId: 'boss:dragon',
    );

    expect(
      await CelebrationPreferences.seenIds(
        userId: 'user-1',
        familyId: 'family-1',
      ),
      {'boss:dragon'},
    );
    expect(
      await CelebrationPreferences.seenIds(
        userId: 'user-2',
        familyId: 'family-1',
      ),
      isEmpty,
    );
  });
}
