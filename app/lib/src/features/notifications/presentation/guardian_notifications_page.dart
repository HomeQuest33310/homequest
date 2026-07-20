import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/dashboard_home_button.dart';
import '../domain/guardian_notification.dart';
import '../providers/notifications_provider.dart';

class GuardianNotificationsPage extends ConsumerStatefulWidget {
  const GuardianNotificationsPage({super.key});

  @override
  ConsumerState<GuardianNotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<GuardianNotificationsPage> {
  bool unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Notifications du royaume'),
      ),
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
                      ref.invalidate(myNotificationsProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          final visibleItems = unreadOnly
              ? items.where((item) => !item.isRead).toList()
              : items;
          return Column(
            children: [
              const _GuidanceBanner(),
              Expanded(
                child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myNotificationsProvider);
            await ref.read(myNotificationsProvider.future);
          },
          child: visibleItems.isEmpty
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
                  itemCount: visibleItems.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Row(
                        children: [
                          FilterChip(
                            label: const Text('Non lues'),
                            selected: unreadOnly,
                            onSelected: (_) => setState(() => unreadOnly = !unreadOnly),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: items.any((item) => !item.isRead)
                                ? () => ref.read(notificationsControllerProvider.notifier).markAllRead()
                                : null,
                            child: const Text('Tout marquer comme lu'),
                          ),
                        ],
                      );
                    }
                    final notification = visibleItems[index - 1];
                    return _NotificationCard(
                      notification: notification,
                      onTap: notification.isRead
                        ? null
                        : () => ref
                            .read(notificationsControllerProvider.notifier)
                            .markRead(notification.id),
                      onAction: notification.actionRoute == null
                          ? null
                          : () async {
                              if (!notification.isRead) {
                                await ref
                                    .read(notificationsControllerProvider.notifier)
                                    .markRead(notification.id);
                              }
                              if (context.mounted) {
                                context.go(notification.actionRoute!);
                              }
                            },
                  );
                  },
                ),
        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner();

  @override
  Widget build(BuildContext context) => const Card(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: const ListTile(
          leading: Icon(Icons.lightbulb_outline),
          title: Text('Votre guide du royaume'),
          subtitle: Text(
            'Chaque message explique ce qui se passe et vous propose une action pour continuer votre aventure.',
          ),
        ),
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onAction,
  });

  final GuardianNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

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
        trailing: notification.actionRoute == null
            ? (notification.isRead
                ? const Icon(Icons.done, size: 18)
                : const Icon(Icons.circle, size: 12))
            : TextButton(
                onPressed: onAction,
                child: Text(notification.actionLabel ?? 'Ouvrir'),
              ),
      ),
    );
  }
}
