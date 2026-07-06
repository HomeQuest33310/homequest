import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  int _indexFromLocation(String location) {
    if (location.startsWith('/quests')) return 1;
    if (location.startsWith('/boss')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/family');
            case 1: context.go('/quests');
            case 2: context.go('/boss');
            case 3: context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.castle_outlined), label: 'Famille'),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Quêtes'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Boss'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
