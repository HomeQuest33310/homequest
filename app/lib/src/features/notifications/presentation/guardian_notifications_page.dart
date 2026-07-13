import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/guardian_notification.dart';
import '../providers/notifications_provider.dart';

class GuardianNotificationsPage extends ConsumerWidget {
  const GuardianNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(guardianNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications du royaume')),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Impossible de charger les notifications : $error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(guardianNotificationsProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(guardianNotificationsProvider);
            await ref.read(guardianNotificationsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.notifications_none, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Aucune notification pour le moment.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _NotificationCard(
                    notification: items[index],
                    onTap: items[index].isRead
                        ? null
                        : () => ref
                            .read(notificationsControllerProvider.notifier)
                            .markRead(items[index].id),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final GuardianNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notification.isRead
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.primaryContainer;

    return Card(
      color: color,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          notification.isRead
              ? Icons.notifications_outlined
              : Icons.notification_important,
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(notification.body),
        ),
        trailing: notification.isRead
            ? const Icon(Icons.done, size: 18)
            : const Tooltip(
                message: 'Toucher pour marquer comme lue',
                child: Icon(Icons.circle, size: 12),
              ),
      ),
    );
  }
}
