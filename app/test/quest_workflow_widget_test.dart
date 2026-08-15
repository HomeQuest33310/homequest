import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/completions/domain/mission_assignment.dart';
import 'package:homequestoria/src/features/completions/presentation/my_missions_page.dart';
import 'package:homequestoria/src/features/completions/providers/completions_provider.dart';

MissionAssignment _mission({
  required String id,
  required String frequency,
  required String status,
  required bool availableNow,
  DateTime? nextAvailableAt,
  String? rejectionReason,
}) {
  return MissionAssignment.fromMap({
    'assignment_id': 'assignment-$id',
    'assigned_at': '2026-08-15T08:00:00Z',
    'is_available_now': availableNow,
    'next_available_at': nextAvailableAt?.toIso8601String(),
    'quest': {
      'id': id,
      'family_id': 'family-1',
      'created_by': 'guardian-1',
      'title': 'Mission $id',
      'real_task': 'Réaliser $id',
      'xp_reward': 10,
      'gold_reward': 5,
      'boss_damage': 1,
      'frequency': frequency,
      'requires_approval': true,
      'status': 'active',
      'created_at': '2026-08-15T08:00:00Z',
    },
    'completion': {
      'id': 'completion-$id',
      'status': status,
      'completed_at': '2026-08-15T09:00:00Z',
      'rejection_reason': rejectionReason,
    },
  });
}

Widget _pageWithMissions(List<MissionAssignment> missions) {
  return ProviderScope(
    overrides: [
      myMissionsProvider.overrideWith((ref) async => missions),
    ],
    child: const MaterialApp(home: MyMissionsPage()),
  );
}

void main() {
  testWidgets('une quête unique approuvée disparaît des missions actives',
      (tester) async {
    final daily = _mission(
      id: 'quotidienne',
      frequency: 'daily',
      status: 'approved',
      availableNow: false,
      nextAvailableAt: DateTime.utc(2026, 8, 16, 8),
    );
    final once = _mission(
      id: 'unique',
      frequency: 'once',
      status: 'approved',
      availableNow: false,
    );

    await tester.pumpWidget(_pageWithMissions([daily, once]));
    await tester.pumpAndSettle();

    expect(find.text('Terminées pour cette période'), findsOneWidget);
    expect(find.text('Mission quotidienne'), findsOneWidget);
    expect(find.text('Mission unique'), findsNothing);
  });

  testWidgets('une quête refusée reste visible avec son motif de reprise',
      (tester) async {
    await tester.pumpWidget(
      _pageWithMissions([
        _mission(
          id: 'refusee',
          frequency: 'once',
          status: 'rejected',
          availableNow: true,
          rejectionReason: 'Photo insuffisante',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mission refusee'), findsOneWidget);
    expect(find.textContaining('Photo insuffisante'), findsOneWidget);
    expect(find.text('Mission accomplie'), findsOneWidget);
  });
}
