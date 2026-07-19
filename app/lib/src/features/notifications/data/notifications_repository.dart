import '../domain/guardian_notification.dart';

abstract class NotificationsRepository {
  Future<List<GuardianNotification>> listForMember(String familyId);

  Future<void> markRead(String notificationId);

  Future<void> markAllRead(String familyId);
}
