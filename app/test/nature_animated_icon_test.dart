import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/core/widgets/nature_animated_icon.dart';

void main() {
  test('chooses a motion that matches each icon nature', () {
    expect(questNatureMotion('laundry'), NatureMotion.spin);
    expect(questNatureMotion('kitchen'), NatureMotion.bounce);
    expect(questNatureMotion('outdoor'), NatureMotion.sway);
    expect(avatarNatureMotion('akatsuki_ninja'), NatureMotion.dash);
    expect(avatarNatureMotion('totoro'), NatureMotion.breathe);
    expect(kingdomNatureMotion('🏰'), NatureMotion.glow);
  });

  testWidgets('plays once and only replays for a new screen', (tester) async {
    await tester.pumpWidget(_testApp(replayKey: 'screen-a'));
    expect(_isIdentity(tester), isFalse);

    await tester.pump(const Duration(seconds: 1));
    expect(_isIdentity(tester), isTrue);

    await tester.pumpWidget(_testApp(replayKey: 'screen-a'));
    expect(_isIdentity(tester), isTrue);

    await tester.pumpWidget(_testApp(replayKey: 'screen-b'));
    expect(_isIdentity(tester), isFalse);
  });

  testWidgets('stays still when reduced motion is enabled', (tester) async {
    await tester.pumpWidget(
      _testApp(replayKey: 'screen-a', disableAnimations: true),
    );

    expect(_isIdentity(tester), isTrue);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

Widget _testApp({required String replayKey, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: NatureAnimatedIcon(
            motion: NatureMotion.pop,
            replayKey: replayKey,
            child: const Text('🧹'),
          ),
        ),
      ),
    ),
  );
}

bool _isIdentity(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('nature-icon-transform')),
  );
  final expected = Matrix4.identity().storage;
  final actual = transform.transform.storage;
  for (var index = 0; index < actual.length; index++) {
    if ((actual[index] - expected[index]).abs() > 0.0001) return false;
  }
  return true;
}
