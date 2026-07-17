import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/hq_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const skills = [
      ('🍳', 'Cuisine', 3),
      ('📚', 'Savoir', 4),
      ('🌿', 'Nature', 2),
      ('🎨', 'Créativité', 3),
      ('❤️', 'Entraide', 4),
    ];

    return HqPage(
      title: 'Profil',
      actions: [
        IconButton(
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aventurier du Royaume',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Harmonie : Or'),
          const SizedBox(height: 16),
          for (final skill in skills)
            Card(
              child: ListTile(
                leading: Text(skill.$1, style: const TextStyle(fontSize: 28)),
                title: Text(skill.$2),
                subtitle: Text('${'★' * skill.$3}${'☆' * (5 - skill.$3)}'),
              ),
            ),
        ],
      ),
    );
  }
}
