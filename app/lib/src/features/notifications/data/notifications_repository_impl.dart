import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/guardian_notification.dart';
import 'notifications_repository.dart';

class SupabaseNotificationsRepository implements NotificationsRepository {
  const SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuardianNotification>> listForMember(String familyId) async {
    dynamic data;
    try {
      data = await _client.rpc(
        'list_my_notifications',
        params: {'p_family_id': familyId},
      );
    } on PostgrestException catch (error) {
      // Allows an older deployed database to keep loading guardian alerts
      // until the notifications-center migration is applied.
      if (error.code != 'PGRST202') rethrow;
      try {
        data = await _client.rpc(
          'list_my_guardian_notifications',
          params: {'p_family_id': familyId},
        );
      } on PostgrestException catch (fallbackError) {
        if (fallbackError.message.contains('Only active guardians')) {
          return const [];
        }
        rethrow;
      }
    }

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
    try {
      await _client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      await _client.rpc(
        'mark_guardian_notification_read',
        params: {'p_notification_id': notificationId},
      );
    }
  }

  @override
  Future<void> markAllRead(String familyId) async {
    try {
      await _client.rpc('mark_all_notifications_read', params: {'p_family_id': familyId});
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
    }
  }
}
