import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/dashboard_home_button.dart';
import '../../../core/widgets/nature_animated_icon.dart';

import '../domain/mission_assignment.dart';
import '../providers/completions_provider.dart';

class MyMissionsPage extends ConsumerStatefulWidget {
  const MyMissionsPage({super.key});

  @override
  ConsumerState<MyMissionsPage> createState() => _MyMissionsPageState();
}

class _MyMissionsPageState extends ConsumerState<MyMissionsPage> {
  Timer? _availabilityTimer;
  DateTime? _scheduledRefreshAt;

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        data: (items) {
          _scheduleAvailabilityRefresh(items);
          return RefreshIndicator(
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
                : _MissionSections(
                    missions: items,
                    isLoading: action.isLoading,
                    onComplete: (mission) => _submit(context, ref, mission),
                    onLeave: (mission) => _leave(context, ref, mission),
                  ),
          );
        },
      ),
    );
  }

  void _scheduleAvailabilityRefresh(List<MissionAssignment> missions) {
    final now = DateTime.now();
    final futureDates = missions
        .map((mission) => mission.nextAvailableAt)
        .whereType<DateTime>()
        .where((date) => date.isAfter(now))
        .toList();
    final nextRefresh = futureDates.isEmpty
        ? null
        : futureDates.reduce(
            (first, second) => first.isBefore(second) ? first : second,
          );

    if (nextRefresh == _scheduledRefreshAt) return;

    _availabilityTimer?.cancel();
    _scheduledRefreshAt = nextRefresh;
    if (nextRefresh == null) return;

    _availabilityTimer = Timer(
      nextRefresh.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        _scheduledRefreshAt = null;
        ref.invalidate(myMissionsProvider);
      },
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

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    MissionAssignment mission,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter la mission ?'),
        content: Text(
          '« ${mission.quest.title} » ne figurera plus dans vos missions. '
          'Les accomplissements et récompenses déjà obtenus seront conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout),
            label: const Text('Quitter la mission'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(completionControllerProvider.notifier)
        .leave(mission.quest.id);
    if (!context.mounted) return;
    final state = ref.read(completionControllerProvider);
    final message = success
        ? 'Vous avez quitté la mission.'
        : 'Impossible de quitter la mission : ${state.error}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _MissionSections extends StatelessWidget {
  const _MissionSections({
    required this.missions,
    required this.isLoading,
    required this.onComplete,
    required this.onLeave,
  });

  final List<MissionAssignment> missions;
  final bool isLoading;
  final ValueChanged<MissionAssignment> onComplete;
  final ValueChanged<MissionAssignment> onLeave;

  @override
  Widget build(BuildContext context) {
    final completedForPeriod = missions.where(_isCompletedForPeriod).toList();
    final missionsToDo =
        missions.where((mission) => !_isCompletedForPeriod(mission)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (missionsToDo.isNotEmpty) ...[
          const _MissionSectionTitle(
            icon: Icons.task_alt,
            title: 'Missions à réaliser',
          ),
          const SizedBox(height: 10),
          for (final mission in missionsToDo) ...[
            _MissionCard(
              mission: mission,
              isLoading: isLoading,
              onComplete: () => onComplete(mission),
              onLeave: () => onLeave(mission),
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (completedForPeriod.isNotEmpty) ...[
          if (missionsToDo.isNotEmpty) const SizedBox(height: 12),
          const _MissionSectionTitle(
            icon: Icons.event_available,
            title: 'Terminées pour cette période',
          ),
          const SizedBox(height: 4),
          Text(
            'Les missions quotidiennes reviennent chaque jour à l’heure '
            'prévue. Les missions hebdomadaires reviennent sept jours après '
            'leur dernière réalisation.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          for (final mission in completedForPeriod) ...[
            Opacity(
              opacity: 0.82,
              child: _MissionCard(
                mission: mission,
                isLoading: isLoading,
                onComplete: () => onComplete(mission),
                onLeave: () => onLeave(mission),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  bool _isCompletedForPeriod(MissionAssignment mission) {
    return !mission.isAvailableNow &&
        mission.completion?.status == 'approved' &&
        mission.quest.frequency != 'once';
  }
}

class _MissionSectionTitle extends StatelessWidget {
  const _MissionSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.isLoading,
    required this.onComplete,
    required this.onLeave,
  });

  final MissionAssignment mission;
  final bool isLoading;
  final VoidCallback onComplete;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final completion = mission.completion;
    final isPending = completion?.status == 'pending';
    final isApprovedOnce =
        completion?.status == 'approved' && mission.quest.frequency == 'once';
    final isCompletedForCurrentPeriod =
        completion?.status == 'approved' && !mission.isAvailableNow;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NatureAnimatedIcon(
                  motion: questNatureMotion(mission.quest.regionKey),
                  child: Text(
                    mission.quest.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    mission.quest.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
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
            else if (isCompletedForCurrentPeriod)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Chip(
                    avatar: Icon(Icons.verified, size: 18),
                    label: Text('Terminée pour cette période'),
                  ),
                  if (mission.nextAvailableAt != null)
                    Text(
                      'De nouveau disponible le '
                      '${DateFormat('dd/MM à HH:mm').format(
                        mission.nextAvailableAt!.toLocal(),
                      )}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: isLoading ? null : onComplete,
                icon: const Icon(Icons.task_alt),
                label: const Text('Mission accomplie'),
              ),
            if (!isPending && !isApprovedOnce) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onLeave,
                icon: const Icon(Icons.logout),
                label: const Text('Quitter la mission'),
              ),
            ],
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
