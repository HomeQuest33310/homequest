import 'package:flutter/material.dart';

import '../../domain/quest.dart';

class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.onEdit,
    required this.onAssign,
    required this.onArchive,
  });

  final Quest quest;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quest.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text('Tâche réelle : ${quest.realTask}'),
            if ((quest.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(quest.description!),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatBadge(icon: Icons.star, label: '${quest.xpReward} XP'),
                _StatBadge(icon: Icons.monetization_on, label: '${quest.goldReward} Or'),
                _StatBadge(icon: Icons.gps_fixed, label: '${quest.bossDamage} dégâts'),
                _StatBadge(icon: Icons.repeat, label: quest.frequency),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                ),
                OutlinedButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Assigner'),
                ),
                OutlinedButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archiver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}