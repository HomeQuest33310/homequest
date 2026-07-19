import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/notifications_repository.dart';
import '../data/notifications_repository_impl.dart';
import '../domain/guardian_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => SupabaseNotificationsRepository(ref.watch(supabaseProvider)),
);

final myNotificationsProvider =
    FutureProvider<List<GuardianNotification>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  final member = await ref.watch(currentFamilyMemberProvider.future);
  if (family == null || member == null || !member.isActive) return const [];

  return ref.watch(notificationsRepositoryProvider).listForMember(family.id);
});

final unreadNotificationsProvider = Provider<int>((ref) {
  return ref.watch(myNotificationsProvider).maybeWhen(
        data: (items) => items.where((item) => !item.isRead).length,
        orElse: () => 0,
      );
});

final guardianNotificationsProvider = myNotificationsProvider;
final unreadGuardianNotificationsProvider = unreadNotificationsProvider;

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, AsyncValue<void>>(
  (ref) => NotificationsController(ref),
);

class NotificationsController extends StateNotifier<AsyncValue<void>> {
  NotificationsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> markRead(String notificationId) async {
    state = const AsyncLoading();
    try {
      await _ref.read(notificationsRepositoryProvider).markRead(notificationId);
      _ref.invalidate(myNotificationsProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> markAllRead() async {
    state = const AsyncLoading();
    try {
      final family = await _ref.read(currentFamilyProvider.future);
      if (family == null) throw StateError('Royaume introuvable');
      await _ref.read(notificationsRepositoryProvider).markAllRead(family.id);
      _ref.invalidate(myNotificationsProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
