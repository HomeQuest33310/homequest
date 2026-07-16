import 'package:flutter/material.dart';

import '../../domain/quest.dart';
import '../../domain/quest_suggestion.dart';

class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.onEdit,
    required this.onAssign,
    required this.onArchive,
    this.onSelfAssign,
  });

  final Quest quest;
  final VoidCallback? onEdit;
  final VoidCallback? onAssign;
  final VoidCallback? onArchive;
  final VoidCallback? onSelfAssign;

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
              '${quest.emoji} ${quest.title}',
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatBadge(
                  icon: Icons.location_on_outlined,
                  label: questLocationLabels[quest.regionKey] ??
                      quest.regionKey ??
                      'Autre lieu',
                ),
                _StatBadge(
                  icon: Icons.auto_awesome,
                  label: quest.element,
                ),
                _StatBadge(
                  icon: Icons.signal_cellular_alt,
                  label: List.filled(quest.difficulty, '⭐').join(),
                ),
              ],
            ),
            if (quest.skillRewards.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quest.skillRewards
                    .map(
                      (reward) => Chip(
                        avatar: Text(reward.icon),
                        label: Text(
                          '${reward.name.isEmpty ? reward.skillId : reward.name} '
                          '+${reward.xpReward}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            _AssignmentBadge(assignees: quest.assignees),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatBadge(icon: Icons.star, label: '${quest.xpReward} XP'),
                _StatBadge(
                    icon: Icons.monetization_on,
                    label: '${quest.goldReward} Or'),
                _StatBadge(
                    icon: Icons.gps_fixed, label: '${quest.bossDamage} dégâts'),
                _StatBadge(icon: Icons.repeat, label: quest.frequencyLabel),
                _StatBadge(
                  icon: quest.requiresApproval
                      ? Icons.fact_check_outlined
                      : Icons.bolt_outlined,
                  label: quest.requiresApproval
                      ? 'Validation requise'
                      : 'Validation automatique',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (onSelfAssign != null)
                  FilledButton.icon(
                    onPressed: onSelfAssign,
                    icon: const Icon(Icons.back_hand_outlined),
                    label: const Text('Prendre cette mission'),
                  ),
                if (onEdit != null)
                  FilledButton.tonalIcon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier'),
                  ),
                if (onAssign != null)
                  OutlinedButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Assigner'),
                  ),
                if (onArchive != null)
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

class _AssignmentBadge extends StatelessWidget {
  const _AssignmentBadge({required this.assignees});

  final List<QuestAssignee> assignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecruiting = assignees.isEmpty;
    final label = isRecruiting
        ? 'Recrutement · Mission libre'
        : 'Assignée à ${assignees.map((member) => member.displayName).join(', ')}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isRecruiting
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(
              isRecruiting ? Icons.campaign_outlined : Icons.people_outline,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge,
              ),
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
