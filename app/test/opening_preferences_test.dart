import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/opening/data/opening_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first awakening is only shown once', () async {
    expect(await OpeningPreferences.shouldShowFirstAwakening(), isTrue);

    await OpeningPreferences.markFirstAwakeningSeen();

    expect(await OpeningPreferences.shouldShowFirstAwakening(), isFalse);
  });

  test('kingdom arrivals are remembered independently', () async {
    expect(
      await OpeningPreferences.shouldShowKingdomArrival('invitation-a'),
      isTrue,
    );
    expect(
      await OpeningPreferences.shouldShowKingdomArrival('invitation-b'),
      isTrue,
    );

    await OpeningPreferences.markKingdomArrivalSeen('invitation-a');

    expect(
      await OpeningPreferences.shouldShowKingdomArrival('invitation-a'),
      isFalse,
    );
    expect(
      await OpeningPreferences.shouldShowKingdomArrival('invitation-b'),
      isTrue,
    );
  });

  test('sound preference defaults to enabled and can be disabled', () async {
    expect(await OpeningPreferences.isSoundEnabled(), isTrue);

    await OpeningPreferences.setSoundEnabled(false);

    expect(await OpeningPreferences.isSoundEnabled(), isFalse);
  });
}
