import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/completions/domain/mission_assignment.dart';
import 'package:homequestoria/src/features/completions/domain/pending_completion.dart';
import 'package:homequestoria/src/features/quests/domain/quest.dart';

MissionAssignment _assignment({
  required String frequency,
  required String status,
  required bool availableNow,
  DateTime? nextAvailableAt,
}) {
  return MissionAssignment.fromMap({
    'assignment_id': 'assignment-1',
    'assigned_at': '2026-08-15T08:00:00Z',
    'is_available_now': availableNow,
    'next_available_at': nextAvailableAt?.toIso8601String(),
    'quest': {
      'id': 'quest-$frequency',
      'family_id': 'family-1',
      'created_by': 'guardian-1',
      'title': 'Mission $frequency',
      'real_task': 'Réaliser la mission',
      'xp_reward': 10,
      'gold_reward': 5,
      'boss_damage': 1,
      'frequency': frequency,
      'requires_approval': true,
      'status': 'active',
      'created_at': '2026-08-15T08:00:00Z',
    },
    'completion': {
      'id': 'completion-1',
      'status': status,
      'completed_at': '2026-08-15T09:00:00Z',
      'rejection_reason': status == 'rejected' ? 'À refaire' : null,
    },
  });
}

void main() {
  test('une quête unique approuvée reste indisponible', () {
    final mission = _assignment(
      frequency: 'once',
      status: 'approved',
      availableNow: false,
    );

    expect(mission.quest.frequency, 'once');
    expect(mission.completion?.status, 'approved');
    expect(mission.isAvailableNow, isFalse);
    expect(mission.nextAvailableAt, isNull);
  });

  test('une quête quotidienne terminée indique sa prochaine disponibilité', () {
    final next = DateTime.utc(2026, 8, 16, 8);
    final mission = _assignment(
      frequency: 'daily',
      status: 'approved',
      availableNow: false,
      nextAvailableAt: next,
    );

    expect(mission.quest.frequency, 'daily');
    expect(mission.isAvailableNow, isFalse);
    expect(mission.nextAvailableAt, next);
  });

  test('une quête hebdomadaire terminée indique la semaine suivante', () {
    final next = DateTime.utc(2026, 8, 22, 8);
    final mission = _assignment(
      frequency: 'weekly',
      status: 'approved',
      availableNow: false,
      nextAvailableAt: next,
    );

    expect(mission.quest.frequency, 'weekly');
    expect(mission.isAvailableNow, isFalse);
    expect(mission.nextAvailableAt, next);
  });

  test('une quête refusée conserve sa raison et peut être reprise', () {
    final mission = _assignment(
      frequency: 'once',
      status: 'rejected',
      availableNow: true,
    );

    expect(mission.completion?.status, 'rejected');
    expect(mission.completion?.rejectionReason, 'À refaire');
    expect(mission.isAvailableNow, isTrue);
  });

  test('une validation en attente reste distincte d une quête terminée', () {
    final mission = _assignment(
      frequency: 'daily',
      status: 'pending',
      availableNow: false,
    );

    expect(mission.completion?.status, 'pending');
    expect(mission.completion?.status, isNot('approved'));
  });

  test('les assignations conservent les noms complets, espaces compris', () {
    final quest = Quest.fromMap({
      'id': 'quest-assignees',
      'family_id': 'family-1',
      'created_by': 'guardian-1',
      'title': 'Mission assignée',
      'real_task': 'Tester les assignations',
      'xp_reward': 10,
      'gold_reward': 5,
      'boss_damage': 1,
      'frequency': 'once',
      'requires_approval': true,
      'status': 'active',
      'created_at': '2026-08-15T08:00:00Z',
      'assignees': [
        {
          'member_id': 'member-1',
          'user_id': 'user-1',
          'display_name': 'Marc Test',
          'role': 'adventurer',
        },
        {
          'member_id': 'member-2',
          'user_id': 'user-2',
          'display_name': 'Lina Martin',
          'role': 'guardian',
        },
      ],
    });

    expect(quest.assignees.map((assignee) => assignee.displayName),
        containsAll(<String>['Marc Test', 'Lina Martin']));
  });

  test('une notification de validation expose bien les gains', () {
    final completion = PendingCompletion.fromMap({
      'id': 'completion-1',
      'quest_id': 'quest-1',
      'quest_title': 'Mission récompensée',
      'real_task': 'Réaliser la mission',
      'completed_by': 'user-1',
      'display_name': 'Marc Test',
      'completed_at': '2026-08-15T09:00:00Z',
      'xp_reward': 25,
      'gold_reward': 10,
      'boss_damage': 3,
    });

    expect(completion.displayName, 'Marc Test');
    expect(completion.xpReward, 25);
    expect(completion.goldReward, 10);
    expect(completion.bossDamage, 3);
  });
}
