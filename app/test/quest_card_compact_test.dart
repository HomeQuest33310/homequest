import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/quests/domain/quest.dart';
import 'package:homequestoria/src/features/quests/presentation/widgets/quest_card.dart';

void main() {
  final quest = Quest(
    id: 'quest-1',
    familyId: 'family-1',
    createdBy: 'guardian-1',
    title: 'Le Lavage des Artefacts Anciens',
    realTask: 'Faire la vaisselle',
    description: 'Rendre leur éclat aux assiettes du Royaume.',
    regionKey: 'kitchen',
    emoji: '🍽️',
    element: 'Eau',
    difficulty: 2,
    xpReward: 100,
    goldReward: 20,
    bossDamage: 15,
    frequency: 'daily',
    requiresApproval: true,
    status: 'active',
    createdAt: DateTime.utc(2026, 7, 19),
  );

  Widget compactCard({
    VoidCallback? onSelfAssign,
    VoidCallback? onEdit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: 390,
              child: QuestCard(
                quest: quest,
                compactOnMobile: true,
                onSelfAssign: onSelfAssign,
                onEdit: onEdit,
                onAssign: null,
                onArchive: null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('affiche le résumé et la prise de mission sur smartphone',
      (tester) async {
    var assignments = 0;
    await tester.pumpWidget(
      compactCard(onSelfAssign: () => assignments++),
    );

    expect(find.text('Le Lavage des Artefacts Anciens'), findsOneWidget);
    expect(find.text('Faire la vaisselle'), findsOneWidget);
    expect(find.text('Prendre cette mission'), findsOneWidget);
    expect(find.text('Quotidien'), findsNothing);
    expect(find.text('Validation requise'), findsNothing);

    await tester.tap(find.text('Prendre cette mission'));
    expect(assignments, 1);
  });

  testWidgets('un double-appui agrandit la quête et révèle ses actions',
      (tester) async {
    await tester.pumpWidget(
      compactCard(onSelfAssign: () {}, onEdit: () {}),
    );

    await tester.tap(find.text('Le Lavage des Artefacts Anciens'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Le Lavage des Artefacts Anciens'));
    await tester.pumpAndSettle();

    expect(find.text('Quotidien'), findsOneWidget);
    expect(find.text('Validation requise'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Prendre cette mission'), findsOneWidget);
  });

  testWidgets('utilise une bordure propre au lieu de la quête', (tester) async {
    await tester.pumpWidget(compactCard(onSelfAssign: () {}));

    final card = tester.widget<Card>(find.byType(Card));
    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.side.color, questLocationBorderColor('kitchen'));
    expect(
      questLocationBorderColor('kitchen'),
      isNot(questLocationBorderColor('laundry')),
    );
  });
}
