import 'package:flutter/material.dart';

import '../../../core/widgets/dashboard_home_button.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Le Royaume'),
      ),
      body: ListView(
        children: const [
          _KingdomCard(),
          _MemberCard(name: 'Papa', role: 'Gardien', level: 2),
          _MemberCard(name: 'Emma', role: 'Aventurière', level: 3),
          _MemberCard(name: 'Mamie', role: 'Mercenaire', level: 1),
        ],
      ),
    );
  }
}

class _KingdomCard extends StatelessWidget {
  const _KingdomCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏰 Royaume de la Maison',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Niveau 1 · Le campement commence à prendre vie.'),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard(
      {required this.name, required this.role, required this.level});

  final String name;
  final String role;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(name.characters.first)),
        title: Text(name),
        subtitle: Text('$role · Niveau $level'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
