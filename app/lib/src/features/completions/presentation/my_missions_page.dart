import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dashboard_home_button.dart';

import '../domain/mission_assignment.dart';
import '../providers/completions_provider.dart';

class MyMissionsPage extends ConsumerWidget {
  const MyMissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(myMissionsProvider);
    final action = ref.watch(completionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Mes missions'),
      ),
      body: missions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MissionError(
          error: error,
          onRetry: () => ref.invalidate(myMissionsProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myMissionsProvider);
            await ref.read(myMissionsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.explore_outlined, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Aucune mission assignée.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _MissionCard(
                    mission: items[index],
                    isLoading: action.isLoading,
                    onComplete: () => _submit(context, ref, items[index]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    MissionAssignment mission,
  ) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mission accomplie !'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ajouter une note (facultatif)',
            hintText: 'Comment s’est passée la mission ?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check),
            label: const Text('Envoyer'),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !context.mounted) return;

    final success =
        await ref.read(completionControllerProvider.notifier).submit(
              questId: mission.quest.id,
              note: note.isEmpty ? null : note,
            );
    if (!context.mounted) return;
    final state = ref.read(completionControllerProvider);
    final reward = ref.read(completionControllerProvider.notifier).lastReward;
    final message = !success
        ? 'Impossible d’envoyer la mission : ${state.error}'
        : reward == null
            ? 'Mission envoyée au Conseil pour validation.'
            : '+${reward.xp} XP · +${reward.gold} or · '
                '${reward.bossDamage} dégâts';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.isLoading,
    required this.onComplete,
  });

  final MissionAssignment mission;
  final bool isLoading;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final completion = mission.completion;
    final isPending = completion?.status == 'pending';
    final isApprovedOnce =
        completion?.status == 'approved' && mission.quest.frequency == 'once';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mission.quest.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(mission.quest.realTask),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('${mission.quest.xpReward} XP')),
                Chip(label: Text('${mission.quest.goldReward} or')),
                Chip(label: Text('${mission.quest.bossDamage} dégâts')),
              ],
            ),
            if (completion?.status == 'rejected') ...[
              const SizedBox(height: 10),
              Text(
                'À reprendre : ${completion?.rejectionReason ?? 'raison non précisée'}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            if (isPending)
              const Chip(
                avatar: Icon(Icons.hourglass_top, size: 18),
                label: Text('En attente de validation'),
              )
            else if (isApprovedOnce)
              const Chip(
                avatar: Icon(Icons.verified, size: 18),
                label: Text('Mission accomplie'),
              )
            else
              FilledButton.icon(
                onPressed: isLoading ? null : onComplete,
                icon: const Icon(Icons.task_alt),
                label: const Text('Mission accomplie'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MissionError extends StatelessWidget {
  const _MissionError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Impossible de charger les missions : $error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
}
