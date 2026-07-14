import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../family/providers/family_provider.dart';
import '../../family/providers/family_stats_provider.dart';
import '../domain/kingdom_progress.dart';
import '../domain/kingdom_resources.dart';
import '../providers/kingdom_resources_provider.dart';

class KingdomProgressPage extends ConsumerWidget {
  const KingdomProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(kingdomResourcesRealtimeProvider);
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final stats = ref.watch(currentFamilyStatsProvider);
    final resources = ref.watch(currentKingdomResourcesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour au Royaume',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Évolution du Royaume'),
        actions: [
          IconButton(
            tooltip: 'Carnet des légendes',
            onPressed: () => context.go('/kingdom-legend'),
            icon: const Icon(Icons.auto_stories),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProgressError(
          error: error,
          onRetry: () => ref.invalidate(currentFamilyStatsProvider),
        ),
        data: (value) {
          final progress = KingdomProgress.fromStats(value);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentFamilyStatsProvider);
              ref.invalidate(currentKingdomResourcesProvider);
              await Future.wait([
                ref.read(currentFamilyStatsProvider.future),
                ref.read(currentKingdomResourcesProvider.future),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _KingdomStageCard(
                  kingdomName: family?.kingdomName ?? 'Votre Royaume',
                  stats: value,
                  progress: progress,
                ),
                const SizedBox(height: 20),
                resources.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Ressources indisponibles : $error'),
                    ),
                  ),
                  data: (value) => _ResourceChest(resources: value),
                ),
                const SizedBox(height: 20),
                Text(
                  'Carte des constructions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Les bâtiments apparaissent grâce aux efforts collectifs. '
                  'Aucun membre ne porte seul leur progression.',
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth >= 600
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final building in progress.buildings)
                          SizedBox(
                            width: width,
                            child: _BuildingCard(building: building),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResourceChest extends StatelessWidget {
  const _ResourceChest({required this.resources});

  final KingdomResources resources;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🧰', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Réserves du Royaume',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Chaque quête validée enrichit automatiquement '
                        'les réserves selon son élément et sa difficulté.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ResourceTile(
                  emoji: '🪵',
                  label: 'Bois',
                  value: resources.wood,
                ),
                _ResourceTile(
                  emoji: '🪨',
                  label: 'Pierre',
                  value: resources.stone,
                ),
                _ResourceTile(
                  emoji: '🌾',
                  label: 'Provisions',
                  value: resources.provisions,
                ),
                _ResourceTile(
                  emoji: '💎',
                  label: 'Cristaux',
                  value: resources.crystals,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.emoji,
    required this.label,
    required this.value,
  });

  final String emoji;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KingdomStageCard extends StatelessWidget {
  const _KingdomStageCard({
    required this.kingdomName,
    required this.stats,
    required this.progress,
  });

  final String kingdomName;
  final FamilyStats stats;
  final KingdomProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = progress.nextStage;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.tertiaryContainer,
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(progress.stage.emoji,
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kingdomName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Étape actuelle : ${progress.stage.name}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (next != null) ...[
              Row(
                children: [
                  Expanded(child: Text('Prochaine étape : ${next.name}')),
                  Text(
                      '${stats.approvedQuestCount}/${next.requiredQuests} quêtes'),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.stageProgress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
              ),
            ] else
              const Text('Le Royaume a atteint son rang légendaire !'),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.construction, size: 18),
                  label: Text(
                    '${progress.unlockedBuildingCount} bâtiments ouverts',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.task_alt, size: 18),
                  label: Text('${stats.approvedQuestCount} quêtes'),
                ),
                Chip(
                  avatar: const Icon(Icons.local_fire_department, size: 18),
                  label: Text('${stats.defeatedBossCount} boss vaincus'),
                ),
                Chip(
                  avatar: const Icon(Icons.card_giftcard, size: 18),
                  label: Text('${stats.deliveredRewardCount} récompenses'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({required this.building});

  final KingdomBuilding building;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: building.isUnlocked ? scheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(building.emoji, style: const TextStyle(fontSize: 38)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    building.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  building.isUnlocked ? Icons.verified : Icons.lock_outline,
                  color: building.isUnlocked
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(building.description),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: building.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 7),
            Text(
              building.isUnlocked ? 'Bâtiment débloqué' : building.goalLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: building.isUnlocked
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressError extends StatelessWidget {
  const _ProgressError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.castle_outlined, size: 46),
            const SizedBox(height: 12),
            Text(
              'Impossible d’afficher l’évolution du Royaume : $error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
