import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/completions/domain/mission_assignment.dart';

void main() {
  test('reads the next recurring availability returned by Supabase', () {
    final mission = MissionAssignment.fromMap({
      'assignment_id': 'assignment-1',
      'assigned_at': '2026-07-19T08:00:00Z',
      'is_available_now': false,
      'next_available_at': '2026-07-26T08:00:00Z',
      'quest': {
        'id': 'quest-1',
        'family_id': 'family-1',
        'created_by': 'profile-1',
        'title': 'Le retour du balai',
        'real_task': 'Passer le balai',
        'xp_reward': 10,
        'gold_reward': 5,
        'boss_damage': 2,
        'frequency': 'weekly',
        'requires_approval': true,
        'status': 'active',
        'created_at': '2026-07-19T08:00:00Z',
      },
      'completion': {
        'id': 'completion-1',
        'status': 'approved',
        'completed_at': '2026-07-19T08:00:00Z',
      },
    });

    expect(mission.isAvailableNow, isFalse);
    expect(
      mission.nextAvailableAt,
      DateTime.parse('2026-07-26T08:00:00Z'),
    );
  });
}
