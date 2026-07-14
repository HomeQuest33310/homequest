import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/providers/family_members_provider.dart';
import '../domain/boss.dart';
import '../providers/boss_provider.dart';
import 'boss_form_dialog.dart';

class BossScreen extends ConsumerWidget {
  const BossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bossesAsync = ref.watch(currentFamilyBossesProvider);
    final member = ref.watch(currentFamilyMemberProvider).asData?.value;
    final canManage = member?.role == 'guardian';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antre des Boss'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(currentFamilyBossesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: bossesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Erreur : $error')),
        data: (bosses) {
          final active = bosses.where((boss) => boss.isActive).firstOrNull;
          final history = bosses.where((boss) => !boss.isActive).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (active == null)
                const _EmptyBossCard()
              else
                _BossCard(
                  boss: active,
                  canRetire: canManage,
                  onRetire: () => _retire(context, ref, active),
                ),
              if (canManage) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => BossFormDialog(
                      hasActiveBoss: active != null,
                    ),
                  ),
                  icon: const Icon(Icons.bolt),
                  label: Text(
                    active == null ? 'Invoquer un boss' : 'Changer de boss',
                  ),
                ),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  'Chroniques des anciens boss',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...history.map(
                  (boss) => Card(
                    child: ListTile(
                      leading: Text(
                        boss.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(boss.name),
                      subtitle: Text(
                        boss.status == 'defeated' ? 'Vaincu' : 'Retiré',
                      ),
                      trailing: Text('${boss.currentHp}/${boss.maxHp} PV'),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _retire(
    BuildContext context,
    WidgetRef ref,
    Boss boss,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer ce boss ?'),
        content: Text('${boss.name} quittera le royaume sans être vaincu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(bossControllerProvider.notifier).retireBoss(boss.id);
  }
}

class _BossCard extends StatelessWidget {
  const _BossCard({
    required this.boss,
    required this.canRetire,
    required this.onRetire,
  });

  final Boss boss;
  final bool canRetire;
  final VoidCallback onRetire;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${boss.emoji} ${boss.name}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(boss.element)),
                Chip(label: Text(boss.domainLabel)),
                Chip(label: Text(List.filled(boss.difficulty, '⭐').join())),
                Chip(label: Text('Niveau ${boss.requiredLevel}')),
              ],
            ),
            if (boss.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(boss.description),
            ],
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: boss.healthProgress,
              minHeight: 14,
            ),
            const SizedBox(height: 8),
            Text('${boss.currentHp} / ${boss.maxHp} PV restants'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: boss.skillRewards
                  .map(
                    (skill) => Chip(
                      avatar: Text(skill.icon),
                      label: Text('${skill.name} +${skill.points}'),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text('Récompense prévue : ${boss.xpReward} XP'),
            if (boss.specialItem.isNotEmpty)
              Text('Trésor : ${boss.specialItem}'),
            const SizedBox(height: 12),
            const Text('Chaque quête validée inflige ses dégâts à ce boss.'),
            if (canRetire) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetire,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Retirer ce boss'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyBossCard extends StatelessWidget {
  const _EmptyBossCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Text('🏕️', style: TextStyle(fontSize: 52)),
            SizedBox(height: 12),
            Text('Aucun boss ne menace actuellement le royaume.'),
          ],
        ),
      ),
    );
  }
}
