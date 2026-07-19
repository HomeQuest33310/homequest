import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/nature_animated_icon.dart';
import '../../../../core/widgets/dashboard_home_button.dart';
import '../../../kingdom/providers/kingdom_provider.dart';
import '../../domain/voluntary_quest_request.dart';
import '../../providers/voluntary_quest_requests_provider.dart';

class VoluntaryQuestRequestsPage extends ConsumerWidget {
  const VoluntaryQuestRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
    final isGuardian = kingdom?.membershipRole == 'guardian';
    final requests = ref.watch(voluntaryQuestRequestsProvider);
    final action = ref.watch(voluntaryQuestRequestsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: Text(isGuardian ? 'Initiatives à examiner' : 'Mes initiatives'),
      ),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Impossible de charger les initiatives : $error'),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(voluntaryQuestRequestsProvider);
            await ref.read(voluntaryQuestRequestsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 150),
                    Icon(Icons.volunteer_activism_outlined, size: 64),
                    SizedBox(height: 14),
                    Text(
                      'Aucune initiative héroïque pour le moment.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _RequestCard(
                    request: items[index],
                    isGuardian: isGuardian,
                    isLoading: action.isLoading,
                    onReview: (approve) =>
                        _review(context, ref, items[index], approve),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    VoluntaryQuestRequest request,
    bool approve,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Accepter cette initiative ?' : 'La refuser ?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: approve
                ? 'Message au héros (facultatif)'
                : 'Motif du refus (facultatif)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Accepter' : 'Refuser'),
          ),
        ],
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(voluntaryQuestRequestsControllerProvider.notifier)
        .review(
          requestId: request.id,
          approve: approve,
          note: note.isEmpty ? null : note,
        );
    if (!context.mounted) return;
    final state = ref.read(voluntaryQuestRequestsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? approve
                  ? request.alreadyCompleted
                      ? 'Initiative validée et récompenses distribuées.'
                      : 'Initiative acceptée et mission assignée.'
                  : 'Initiative refusée.'
              : 'Décision impossible : ${state.error}',
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isGuardian,
    required this.isLoading,
    required this.onReview,
  });

  final VoluntaryQuestRequest request;
  final bool isGuardian;
  final bool isLoading;
  final ValueChanged<bool> onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NatureAnimatedIcon(
                  motion: NatureMotion.pop,
                  child: Text(
                    request.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('${request.requesterName} · ${request.realTask}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                Chip(label: Text('${request.xpReward} XP')),
                Chip(label: Text('${request.goldReward} or')),
                Chip(label: Text('${request.bossDamage} dégâts')),
                if (request.alreadyCompleted)
                  const Chip(
                    avatar: Icon(Icons.task_alt, size: 18),
                    label: Text('Déjà accomplie'),
                  ),
              ],
            ),
            if (request.requesterNote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Message : ${request.requesterNote}'),
            ],
            if (request.reviewNote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Réponse du Conseil : ${request.reviewNote}'),
            ],
            if (isGuardian && request.status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : () => onReview(false),
                    icon: const Icon(Icons.close),
                    label: const Text('Refuser'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: isLoading ? null : () => onReview(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Accepter'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      'approved' => ('Acceptée', Icons.verified),
      'rejected' => ('Refusée', Icons.cancel_outlined),
      _ => ('En attente', Icons.hourglass_top),
    };
    return Chip(avatar: Icon(icon, size: 17), label: Text(label));
  }
}
