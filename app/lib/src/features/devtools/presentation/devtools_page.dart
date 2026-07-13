import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../quests/providers/quests_provider.dart';
import 'package:go_router/go_router.dart';

class DevToolsPage extends ConsumerWidget {
  const DevToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final familyAsync = ref.watch(currentFamilyProvider);
    final membersAsync = ref.watch(currentFamilyMembersProvider);
    final questsAsync = ref.watch(currentFamilyQuestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            title: 'Session',
            child: Text(user == null ? 'Aucun utilisateur connecté' : 'User ID: ${user.id}'),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Royaume',
            child: familyAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur: $e'),
              data: (family) => Text(
                family == null
                    ? 'Aucun royaume'
                    : '${family.kingdomName}\nFamily ID: ${family.id}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Membres',
            child: membersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur: $e'),
              data: (members) => Text('${members.length} membre(s)'),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Quêtes',
            child: questsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur: $e'),
              data: (quests) => Text('${quests.length} quête(s) active(s)'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              ref.invalidate(currentFamilyProvider);
              ref.invalidate(currentFamilyMembersProvider);
              ref.invalidate(currentFamilyQuestsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Providers rafraîchis')),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir les providers'),
          ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour au dashboard'),
          ),
        ],
              ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}