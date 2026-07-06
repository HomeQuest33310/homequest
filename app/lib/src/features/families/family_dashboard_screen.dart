import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/hq_page.dart';

class FamilyDashboardScreen extends StatelessWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HqPage(
      title: 'Tableau de bord',
      actions: [
        IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Votre royaume prend vie.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Text('🐉', style: TextStyle(fontSize: 28)),
              title: Text('Dragon de la Poussière'),
              subtitle: Text('Boss MVP — 300 PV'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Text('⚔️', style: TextStyle(fontSize: 28)),
              title: Text('Quêtes'),
              subtitle: Text('La création de quêtes arrive au prochain sprint.'),
            ),
          ),
        ],
      ),
    );
  }
}
