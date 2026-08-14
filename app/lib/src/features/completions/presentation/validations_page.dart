import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dashboard_home_button.dart';

import '../domain/pending_completion.dart';
import '../providers/completions_provider.dart';

class ValidationsPage extends ConsumerWidget {
  const ValidationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCompletionsProvider);
    final action = ref.watch(completionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Conseil des validations'),
      ),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingCompletionsProvider);
            await ref.read(pendingCompletionsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.verified_outlined, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Aucune mission en attente.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ValidationCard(
                    completion: items[index],
                    isLoading: action.isLoading,
                    onApprove: () => _approve(context, ref, items[index]),
                    onReject: () => _reject(context, ref, items[index]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    PendingCompletion completion,
  ) async {
    List<String>? participantIds;
    if (completion.frequency == 'once' &&
        completion.assignedMembers.length > 1) {
      participantIds = await _chooseParticipants(context, completion);
      if (participantIds == null || !context.mounted) return;
    }
    final success = await ref
        .read(completionControllerProvider.notifier)
        .approve(completion.id, participantIds: participantIds);
    if (!context.mounted) return;
    final controller = ref.read(completionControllerProvider.notifier);
    final state = ref.read(completionControllerProvider);
    final reward = controller.lastReward;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success && reward != null
              ? 'Validée : +${reward.xp} XP, +${reward.gold} or, '
                  '${reward.bossDamage} dégâts.'
                  '${reward.participantsCount > 1 ? ' Récompenses réparties entre ${reward.participantsCount} participants.' : ''}'
              : 'Validation impossible : ${state.error}',
        ),
      ),
    );
  }

  Future<List<String>?> _chooseParticipants(
    BuildContext context,
    PendingCompletion completion,
  ) {
    final selected = <String>{completion.completedBy};
    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Qui a réalisé cette quête ?'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: completion.assignedMembers.map((participant) {
                  final isCompleter = participant.memberId == completion.completedBy;
                  return CheckboxListTile(
                    value: selected.contains(participant.memberId),
                    onChanged: isCompleter
                        ? null
                        : (checked) => setState(() {
                              if (checked == true) {
                                selected.add(participant.memberId);
                              } else {
                                selected.remove(participant.memberId);
                              }
                            }),
                    title: Text(participant.displayName),
                    subtitle: isCompleter
                        ? const Text('Personne ayant soumis la réalisation')
                        : null,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected.toList()),
              child: const Text('Valider et répartir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    PendingCompletion completion,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pourquoi reprendre la mission ?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Expliquez de manière encourageante…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Demander de reprendre'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !context.mounted) return;

    final success =
        await ref.read(completionControllerProvider.notifier).reject(
              completionId: completion.id,
              reason: reason,
            );
    if (!context.mounted) return;
    final state = ref.read(completionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Mission renvoyée avec une explication.'
              : 'Erreur : ${state.error}',
        ),
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({
    required this.completion,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
  });

  final PendingCompletion completion;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                completion.questTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('${completion.displayName} · ${completion.realTask}'),
              if ((completion.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('« ${completion.note} »'),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('${completion.xpReward} XP')),
                  Chip(label: Text('${completion.goldReward} or')),
                  Chip(label: Text('${completion.bossDamage} dégâts')),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: isLoading ? null : onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approuver'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onReject,
                    icon: const Icon(Icons.replay),
                    label: const Text('À reprendre'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
