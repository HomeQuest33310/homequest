import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/family/providers/family_members_provider.dart';
import '../../features/family/providers/family_stats_provider.dart';
import '../../features/kingdom/domain/kingdom_progress.dart';
import '../../features/kingdom/providers/kingdom_provider.dart';
import '../../features/profile/presentation/widgets/profile_avatar_view.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  int _indexFromLocation(String location) {
    if (location.startsWith('/quests') ||
        location.startsWith('/quest-requests')) {
      return 1;
    }
    if (location.startsWith('/missions') ||
        location.startsWith('/validations')) {
      return 2;
    }
    if (location.startsWith('/profile') || location.startsWith('/heroes')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(kingdomMembershipRealtimeProvider);
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexFromLocation(location);
    final member = ref.watch(currentFamilyMemberProvider).valueOrNull;
    final stats = ref.watch(currentFamilyStatsProvider).valueOrNull;
    final kingdomEmoji =
        stats == null ? '⛺' : KingdomProgress.fromStats(stats).stage.emoji;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
            case 1:
              context.go('/quests');
            case 2:
              context.go('/missions');
            case 3:
              context.go('/profile');
          }
        },
        destinations: [
          NavigationDestination(
            icon: Text(
              kingdomEmoji,
              style: const TextStyle(fontSize: 23),
              semanticsLabel: 'Étape actuelle du Royaume',
            ),
            label: 'Royaume',
          ),
          const NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Quêtes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'Missions',
          ),
          NavigationDestination(
            icon: ProfileAvatarView(
              avatarKey: member?.avatarKey,
              size: 26,
              semanticLabel: 'Avatar du profil',
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
