import '../domain/guardian_notification.dart';

abstract class NotificationsRepository {
  Future<List<GuardianNotification>> listForGuardian(String familyId);

  Future<void> markRead(String notificationId);
}
