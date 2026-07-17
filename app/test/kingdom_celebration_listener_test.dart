import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/celebrations/presentation/kingdom_celebration_listener.dart';
import 'package:homequestoria/src/features/chronicles/domain/kingdom_legend_entry.dart';

void main() {
  Future<void> openCelebration(
    WidgetTester tester,
    KingdomLegendEntry entry,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              unawaited(
                showKingdomCelebration(context: context, entry: entry),
              );
            },
            child: const Text('Afficher'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Afficher'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('annonce la victoire contre un boss', (tester) async {
    await openCelebration(
      tester,
      KingdomLegendEntry(
        id: 'boss:dragon',
        category: 'boss',
        eventType: 'boss_defeated',
        title: '🐉 Dragon des Cendres',
        body: '',
        status: 'defeated',
        occurredAt: DateTime.utc(2026, 7, 17),
        metadata: const {
          'element': 'Feu',
          'special_item': 'Écaille ardente',
        },
      ),
    );

    expect(find.text('VICTOIRE DU ROYAUME'), findsOneWidget);
    expect(find.text('🐉 Dragon des Cendres'), findsOneWidget);
    expect(find.text('Célébrer la victoire'), findsOneWidget);
  });

  testWidgets('annonce une récompense collective débloquée', (tester) async {
    await openCelebration(
      tester,
      KingdomLegendEntry(
        id: 'reward:festin',
        category: 'reward',
        eventType: 'reward_unlocked',
        title: 'Festin du Royaume',
        body: '',
        status: 'unlocked',
        occurredAt: DateTime.utc(2026, 7, 17),
        metadata: const {
          'completed_quest_count': 10,
          'guardian_quest_count': 10,
        },
      ),
    );

    expect(find.text('RÉCOMPENSE DÉBLOQUÉE'), findsOneWidget);
    expect(find.text('Festin du Royaume'), findsOneWidget);
    expect(find.text('10/10 quêtes accomplies'), findsOneWidget);
    expect(find.text('Découvrir la récompense'), findsOneWidget);
  });
}
