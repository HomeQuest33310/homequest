import 'package:flutter_test/flutter_test.dart';
import 'package:homequestoria/src/features/boss/domain/boss.dart';

void main() {
  test('conserve les participants enregistrés pour un ancien boss', () {
    final boss = Boss.fromMap({
      'id': 'boss-1',
      'family_id': 'family-1',
      'name': 'Dragon',
      'emoji': '🐉',
      'element': 'Feu',
      'domain_label': 'Cuisine',
      'description': '',
      'max_hp': 100,
      'current_hp': 0,
      'difficulty': 3,
      'required_level': 1,
      'xp_reward': 50,
      'special_item': 'Écaille',
      'status': 'defeated',
      'skill_rewards': const [],
      'participant_names': const ['Alice', 'Basile'],
      'created_at': '2026-07-17T12:00:00Z',
    });

    expect(boss.participantNames, ['Alice', 'Basile']);
  });
}
