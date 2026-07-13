import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/guardian_notification.dart';
import 'notifications_repository.dart';

class SupabaseNotificationsRepository implements NotificationsRepository {
  const SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuardianNotification>> listForGuardian(String familyId) async {
    final data = await _client.rpc(
      'list_my_guardian_notifications',
      params: {'p_family_id': familyId},
    );

    return (data as List)
        .map(
          (item) => GuardianNotification.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client.rpc(
      'mark_guardian_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }
}
