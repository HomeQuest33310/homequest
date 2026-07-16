import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/dashboard_home_button.dart';
import '../../domains/domain/domain.dart';
import '../../domains/providers/domains_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../family/providers/family_stats_provider.dart';
import '../domain/kingdom_construction.dart';
import '../domain/kingdom_progress.dart';
import '../domain/kingdom_resources.dart';
import '../providers/kingdom_constructions_provider.dart';
import '../providers/kingdom_provider.dart';
import '../providers/kingdom_resources_provider.dart';

class KingdomProgressPage extends ConsumerWidget {
  const KingdomProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(kingdomResourcesRealtimeProvider);
    ref.watch(kingdomConstructionsRealtimeProvider);
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
    final stats = ref.watch(currentFamilyStatsProvider);
    final resources = ref.watch(currentKingdomResourcesProvider);
    final constructions = ref.watch(currentKingdomConstructionsProvider);
    final domains = ref.watch(currentFamilyDomainsProvider);
    final canManage = kingdom?.membershipRole == 'guardian';

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Royaume'),
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
          final builtCount = constructions.valueOrNull
                  ?.where((building) => building.isBuilt)
                  .length ??
              0;
          final marketReady = constructions.valueOrNull?.any(
                (building) => building.isMarket && building.isBuilt,
              ) ??
              false;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentFamilyStatsProvider);
              ref.invalidate(currentKingdomResourcesProvider);
              ref.invalidate(currentKingdomConstructionsProvider);
              ref.invalidate(currentFamilyDomainsProvider);
              await Future.wait([
                ref.read(currentFamilyStatsProvider.future),
                ref.read(currentKingdomResourcesProvider.future),
                ref.read(currentKingdomConstructionsProvider.future),
                ref.read(currentFamilyDomainsProvider.future),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _KingdomStageCard(
                  kingdomName: family?.kingdomName ?? 'Votre Royaume',
                  stats: value,
                  progress: progress,
                  builtCount: builtCount,
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    onTap: () => context.go('/kingdom-legend'),
                    leading: const Icon(Icons.auto_stories, size: 30),
                    title: const Text('Carnet des légendes'),
                    subtitle: const Text(
                      'Retrouvez toute l’histoire et les exploits du Royaume.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 20),
                _EvolutionBuildingsSection(progress: progress),
                const SizedBox(height: 28),
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
                if (marketReady) ...[
                  const SizedBox(height: 16),
                  _KingdomMarketCard(
                    enabled: canManage,
                    isLoading:
                        ref.watch(kingdomEconomyControllerProvider).isLoading,
                    onConvert: (resourceKey) =>
                        _convertCrystal(context, ref, resourceKey),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Constructions avec les réserves',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  canManage
                      ? 'Ces bâtiments sont différents des bâtiments '
                          'd’évolution. Dépensez les réserves collectives pour '
                          'lancer un chantier ou une amélioration.'
                      : 'Les Gardiens utilisent les réserves collectives pour '
                          'construire ces bâtiments supplémentaires.',
                ),
                const SizedBox(height: 14),
                constructions.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => _InlineError(
                    message: 'Constructions indisponibles : $error',
                    onRetry: () =>
                        ref.invalidate(currentKingdomConstructionsProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Le nouveau système de constructions doit encore '
                              'être activé sur Supabase.',
                            ),
                          ),
                        )
                      : LayoutBuilder(
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
                                for (final building in items)
                                  SizedBox(
                                    width: width,
                                    child: _ConstructionCard(
                                      building: building,
                                      resources: resources.valueOrNull ??
                                          KingdomResources.empty,
                                      canManage: canManage,
                                      isLoading: ref
                                          .watch(
                                            kingdomEconomyControllerProvider,
                                          )
                                          .isLoading,
                                      onStart: () => _startConstruction(
                                        context,
                                        ref,
                                        building,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 28),
                _DomainsSection(domains: domains),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startConstruction(
    BuildContext context,
    WidgetRef ref,
    KingdomConstruction building,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${building.emoji} ${building.actionLabel} ?'),
        content: Text(
          '${building.name}\n\n'
          'Coût : ${_costLabel(building)}\n'
          'Durée : ${_durationLabel(Duration(hours: building.buildHours))}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(building.level == 0 ? 'Construire' : 'Améliorer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(kingdomEconomyControllerProvider.notifier)
        .startConstruction(building.key);
    if (!context.mounted) return;
    _showEconomyResult(
      context,
      ref,
      success: success,
      successMessage: 'Le chantier de ${building.name} est lancé.',
    );
  }

  Future<void> _convertCrystal(
    BuildContext context,
    WidgetRef ref,
    String resourceKey,
  ) async {
    final success = await ref
        .read(kingdomEconomyControllerProvider.notifier)
        .convertCrystal(resourceKey);
    if (!context.mounted) return;
    final label = switch (resourceKey) {
      'wood' => '50 bois',
      'stone' => '30 pierre',
      _ => '100 provisions',
    };
    _showEconomyResult(
      context,
      ref,
      success: success,
      successMessage: 'Conversion réussie : +$label.',
    );
  }

  void _showEconomyResult(
    BuildContext context,
    WidgetRef ref, {
    required bool success,
    required String successMessage,
  }) {
    final error = ref.read(kingdomEconomyControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : _friendlyError(error)),
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
                        'Les quêtes rapportent bois, pierre et provisions. '
                        'Les boss vaincus offrent cristaux et objets spéciaux.',
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
                  emoji: '🥫',
                  label: 'Provisions',
                  value: resources.provisions,
                ),
                _ResourceTile(
                  emoji: '⚡',
                  label: 'Cristaux',
                  value: resources.crystals,
                ),
                _ResourceTile(
                  emoji: '🎁',
                  label: 'Objets de boss',
                  value: resources.bossItemCount,
                ),
              ],
            ),
            if (resources.bossItems.isNotEmpty) ...[
              const Divider(height: 30),
              Text(
                'Butins de boss',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in resources.bossItems)
                    Chip(
                      avatar: Text(item.emoji),
                      label: Text(
                        '${item.name} ×${item.quantity} · Niveau ${item.tier}',
                      ),
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
    required this.builtCount,
  });

  final String kingdomName;
  final FamilyStats stats;
  final KingdomProgress progress;
  final int builtCount;

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
                  avatar: const Icon(Icons.flag_circle, size: 18),
                  label: Text(
                    '${progress.unlockedBuildingCount} bâtiments d’évolution',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.construction, size: 18),
                  label: Text('$builtCount avec les réserves'),
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

class _EvolutionBuildingsSection extends StatelessWidget {
  const _EvolutionBuildingsSection({required this.progress});

  final KingdomProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bâtiments d’évolution',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Ils se débloquent automatiquement grâce aux quêtes et aux exploits '
          'collectifs. Ils ne dépensent aucune réserve du Royaume.',
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
                    child: _EvolutionBuildingCard(building: building),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EvolutionBuildingCard extends StatelessWidget {
  const _EvolutionBuildingCard({required this.building});

  final KingdomBuilding building;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: building.isUnlocked ? scheme.primaryContainer : null,
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
              building.isUnlocked
                  ? 'Débloqué automatiquement'
                  : building.goalLabel,
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

class _ConstructionCard extends StatelessWidget {
  const _ConstructionCard({
    required this.building,
    required this.resources,
    required this.canManage,
    required this.isLoading,
    required this.onStart,
  });

  final KingdomConstruction building;
  final KingdomResources resources;
  final bool canManage;
  final bool isLoading;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final affordable = building.canAfford(resources);

    return Card(
      color: building.isBuilt ? scheme.secondaryContainer : null,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Palier ${building.tier} · Niveau '
                        '${building.level}/${building.maxLevel}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  building.isInProgress
                      ? Icons.construction
                      : building.isMaxLevel
                          ? Icons.workspace_premium
                          : building.isBuilt
                              ? Icons.verified
                              : Icons.lock_open_outlined,
                  color: building.isBuilt || building.isInProgress
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(building.description),
            const SizedBox(height: 7),
            Text(
              building.bonusDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (building.canStart) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _costChips(building),
              ),
              const SizedBox(height: 12),
            ],
            if (building.isInProgress) ...[
              LinearProgressIndicator(
                value: building.constructionProgress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 7),
              Text(
                'Fin dans ${_durationLabel(building.remaining)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (canManage && building.canStart)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: affordable && !isLoading ? onStart : null,
                  icon: Icon(
                    building.level == 0 ? Icons.construction : Icons.upgrade,
                  ),
                  label: Text(
                    affordable
                        ? building.actionLabel
                        : 'Ressources insuffisantes',
                  ),
                ),
              )
            else
              Text(
                building.actionLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: building.isMaxLevel
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

  List<Widget> _costChips(KingdomConstruction value) {
    final costs = <(String, int)>[
      ('🪵', value.woodCost),
      ('🪨', value.stoneCost),
      ('🥫', value.provisionsCost),
      ('⚡', value.crystalsCost),
      ('🎁', value.bossItemsCost),
    ];
    return [
      for (final cost in costs)
        if (cost.$2 > 0)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text('${cost.$1} ${cost.$2}'),
          ),
      if (value.tierThreeItemsCost > 0)
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('dont ${value.tierThreeItemsCost} objets niveau 3'),
        ),
    ];
  }
}

class _KingdomMarketCard extends StatelessWidget {
  const _KingdomMarketCard({
    required this.enabled,
    required this.isLoading,
    required this.onConvert,
  });

  final bool enabled;
  final bool isLoading;
  final ValueChanged<String> onConvert;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏪', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marché du Royaume',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Convertissez un cristal en ressource collective. '
                        'Limites quotidiennes : 100 bois et 60 pierre.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MarketButton(
                  label: '⚡ 1 → 🪵 50',
                  onPressed:
                      enabled && !isLoading ? () => onConvert('wood') : null,
                ),
                _MarketButton(
                  label: '⚡ 1 → 🪨 30',
                  onPressed:
                      enabled && !isLoading ? () => onConvert('stone') : null,
                ),
                _MarketButton(
                  label: '⚡ 1 → 🥫 100',
                  onPressed: enabled && !isLoading
                      ? () => onConvert('provisions')
                      : null,
                ),
              ],
            ),
            if (!enabled) ...[
              const SizedBox(height: 8),
              const Text('Seul un Gardien peut effectuer une conversion.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketButton extends StatelessWidget {
  const _MarketButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message),
        trailing: IconButton(
          tooltip: 'Réessayer',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

String _costLabel(KingdomConstruction building) {
  final parts = <String>[
    if (building.woodCost > 0) '${building.woodCost} bois',
    if (building.stoneCost > 0) '${building.stoneCost} pierre',
    if (building.provisionsCost > 0) '${building.provisionsCost} provisions',
    if (building.crystalsCost > 0) '${building.crystalsCost} cristaux',
    if (building.bossItemsCost > 0) '${building.bossItemsCost} objets de boss',
  ];
  return parts.isEmpty ? 'Gratuit' : parts.join(' · ');
}

String _durationLabel(Duration duration) {
  if (duration <= Duration.zero) return 'quelques secondes';
  if (duration.inDays > 0) {
    final hours = duration.inHours.remainder(24);
    return '${duration.inDays} j${hours > 0 ? ' $hours h' : ''}';
  }
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours} h${minutes > 0 ? ' $minutes min' : ''}';
  }
  return '${duration.inMinutes + 1} min';
}

String _friendlyError(Object? error) {
  final message = error.toString();
  if (message.contains('Not enough kingdom resources')) {
    return 'Les réserves du Royaume sont insuffisantes.';
  }
  if (message.contains('Not enough boss items')) {
    return 'Le Royaume ne possède pas assez d’objets de boss.';
  }
  if (message.contains('Not enough tier 3 boss items')) {
    return 'Il faut davantage d’objets de boss de niveau 3.';
  }
  if (message.contains('Not enough crystals')) {
    return 'Le Royaume ne possède pas assez de cristaux.';
  }
  if (message.contains('Daily wood purchase limit')) {
    return 'La limite quotidienne de bois est atteinte.';
  }
  if (message.contains('Daily stone purchase limit')) {
    return 'La limite quotidienne de pierre est atteinte.';
  }
  if (message.contains('Daily crystal conversion limit')) {
    return 'La limite quotidienne de conversion est atteinte.';
  }
  if (message.contains('Only guardians')) {
    return 'Seul un Gardien peut effectuer cette action.';
  }
  return 'Action impossible : $error';
}

class _DomainsSection extends StatelessWidget {
  const _DomainsSection({required this.domains});

  final AsyncValue<List<Domain>> domains;

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
                const Icon(Icons.domain_outlined, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Domaines du Royaume',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Text(
                        'Les pièces, zones et grandes activités de votre foyer.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            domains.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Impossible de charger les Domaines : $error',
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Text('Aucun Domaine pour le moment.');
                }
                return Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _DomainTile(domain: items[index]),
                      if (index < items.length - 1) const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainTile extends StatelessWidget {
  const _DomainTile({required this.domain});

  final Domain domain;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(_emojiForDomain(domain.domainKind))),
      title: Text(domain.name),
      subtitle: Text(
        domain.isPrimary
            ? 'Domaine principal'
            : _labelForDomain(domain.domainKind),
      ),
      trailing: domain.isPrimary
          ? const Icon(Icons.workspace_premium_outlined)
          : const Icon(Icons.chevron_right),
    );
  }

  String _emojiForDomain(String kind) {
    switch (kind) {
      case 'vacation':
        return '🏖️';
      case 'grandparent':
        return '👵';
      case 'camp':
        return '🏕️';
      case 'custom':
        return '✨';
      case 'home':
      default:
        return '🏠';
    }
  }

  String _labelForDomain(String kind) {
    switch (kind) {
      case 'vacation':
        return 'Maison de vacances';
      case 'grandparent':
        return 'Maison de grand-parent';
      case 'camp':
        return 'Camp ou lieu temporaire';
      case 'custom':
        return 'Domaine personnalisé';
      case 'home':
      default:
        return 'Maison';
    }
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
