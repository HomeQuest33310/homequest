import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/dashboard_home_button.dart';
import '../../boss/domain/boss.dart';
import '../../boss/domain/boss_suggestion.dart';
import '../../boss/presentation/boss_suggestions_dialog.dart';
import '../../boss/providers/boss_provider.dart';
import '../../profile/providers/rpg_profile_provider.dart';
import '../domain/reward_suggestion.dart';
import '../providers/reward_suggestions_provider.dart';

class RewardSuggestionsPage extends ConsumerWidget {
  const RewardSuggestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(rewardSuggestionsRealtimeProvider);
    ref.listen<RewardDecisionNotice?>(
      rewardDecisionNoticeProvider,
      (previous, notice) {
        if (notice == null) return;

        final accepted = notice.status == 'approved';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                accepted
                    ? '✨ Votre souhait « ${notice.title} » a été accepté par les Gardiens.'
                    : 'Le Conseil a refusé votre souhait « ${notice.title} ».',
              ),
              backgroundColor: accepted ? Colors.green.shade700 : null,
            ),
          );
        ref.read(rewardDecisionNoticeProvider.notifier).state = null;
      },
    );

    final profileAsync = ref.watch(currentRpgProfileProvider);
    final suggestionsAsync = ref.watch(currentRewardSuggestionsProvider);
    final bossesAsync = ref.watch(currentFamilyBossesProvider);
    final busy = ref.watch(rewardSuggestionsControllerProvider).isLoading;
    Boss? activeBoss;
    for (final boss in bossesAsync.valueOrNull ?? const <Boss>[]) {
      if (boss.isActive) {
        activeBoss = boss;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Souhaits de récompenses'),
      ),
      floatingActionButton: profileAsync.maybeWhen(
        data: (profile) => FloatingActionButton.extended(
          onPressed: busy ? null : () => _proposeReward(context, ref),
          icon: Icon(
            profile.role == 'guardian'
                ? Icons.emoji_events_outlined
                : Icons.add,
          ),
          label: Text(
            profile.role == 'guardian'
                ? 'Créer une récompense'
                : 'Faire un souhait',
          ),
        ),
        orElse: () => null,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(error: error),
        data: (profile) => suggestionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(error: error),
          data: (suggestions) {
            final priorityQueue = suggestions
                .where((suggestion) => suggestion.isInQuestPriorityQueue)
                .toList();
            final activeSuggestions = suggestions
                .where((suggestion) => !suggestion.isArchived)
                .toList();
            final archivedSuggestions = suggestions
                .where((suggestion) => suggestion.isArchived)
                .toList();
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentRewardSuggestionsProvider);
                await ref.read(currentRewardSuggestionsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  _IntroductionCard(isGuardian: profile.role == 'guardian'),
                  if (priorityQueue.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PriorityExplanationCard(
                      isGuardian: profile.role == 'guardian',
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (suggestions.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.card_giftcard),
                        title: Text('Aucun souhait pour le moment.'),
                        subtitle: Text(
                          'Les propositions de récompenses apparaîtront ici.',
                        ),
                      ),
                    ),
                  if (activeSuggestions.isNotEmpty) ...[
                    const _RewardSectionTitle(
                      icon: Icons.auto_awesome,
                      title: 'Récompenses actives et souhaits',
                    ),
                    const SizedBox(height: 10),
                    for (final suggestion in activeSuggestions) ...[
                      _buildSuggestionCard(
                        context: context,
                        ref: ref,
                        suggestion: suggestion,
                        priorityQueue: priorityQueue,
                        isGuardian: profile.role == 'guardian',
                        busy: busy,
                        activeBoss: activeBoss,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (archivedSuggestions.isNotEmpty) ...[
                    if (activeSuggestions.isNotEmpty)
                      const SizedBox(height: 16),
                    const _RewardSectionTitle(
                      icon: Icons.archive_outlined,
                      title: 'Récompenses archivées',
                      subtitle:
                          'Historique des récompenses retirées des objectifs actifs.',
                    ),
                    const SizedBox(height: 10),
                    for (final suggestion in archivedSuggestions) ...[
                      _buildSuggestionCard(
                        context: context,
                        ref: ref,
                        suggestion: suggestion,
                        priorityQueue: priorityQueue,
                        isGuardian: profile.role == 'guardian',
                        busy: busy,
                        activeBoss: activeBoss,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuggestionCard({
    required BuildContext context,
    required WidgetRef ref,
    required RewardSuggestion suggestion,
    required List<RewardSuggestion> priorityQueue,
    required bool isGuardian,
    required bool busy,
    required Boss? activeBoss,
  }) {
    return _SuggestionCard(
      suggestion: suggestion,
      isGuardian: isGuardian,
      busy: busy,
      priorityPosition: suggestion.isInQuestPriorityQueue
          ? priorityQueue.indexOf(suggestion) + 1
          : null,
      priorityCount: priorityQueue.length,
      onMoveUp: () => _moveReward(
        context,
        ref,
        priorityQueue,
        suggestion,
        -1,
      ),
      onMoveDown: () => _moveReward(
        context,
        ref,
        priorityQueue,
        suggestion,
        1,
      ),
      onReview: () => _reviewReward(
        context,
        ref,
        suggestion,
        activeBoss,
      ),
      onDeliver: () => _deliverReward(
        context,
        ref,
        suggestion,
      ),
      onEdit: () => _editReward(
        context,
        ref,
        suggestion,
      ),
      onArchive: () => _archiveReward(
        context,
        ref,
        suggestion,
      ),
    );
  }

  Future<void> _proposeReward(BuildContext context, WidgetRef ref) async {
    final profile = await ref.read(currentRpgProfileProvider.future);
    if (!context.mounted) return;
    if (profile.role == 'guardian') {
      await _createGuardianGoal(context, ref);
      return;
    }

    final result = await showDialog<_RewardDraft>(
      context: context,
      builder: (_) => const _RewardDraftDialog(),
    );
    if (result == null || !context.mounted) return;

    final success =
        await ref.read(rewardSuggestionsControllerProvider.notifier).propose(
              title: result.title,
              description: result.description,
              questCount: result.questCount,
            );
    if (!context.mounted) return;
    _showResult(context, ref, success, 'Souhait transmis aux Gardiens.');
  }

  Future<void> _reviewReward(
    BuildContext context,
    WidgetRef ref,
    RewardSuggestion suggestion,
    Boss? activeBoss,
  ) async {
    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (_) => _ReviewDialog(
        suggestion: suggestion,
        activeBoss: activeBoss,
      ),
    );
    if (result == null || !context.mounted) return;

    final success =
        await ref.read(rewardSuggestionsControllerProvider.notifier).review(
              suggestionId: suggestion.id,
              status: result.status,
              title: result.title,
              description: result.description,
              questCount: result.questCount,
              boss: _bossPayload(result),
              replaceActiveBoss: result.replaceActiveBoss,
            );
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success,
      result.status == 'approved'
          ? 'Souhait approuvé et défi défini.'
          : 'Souhait refusé.',
    );
  }

  Future<void> _createGuardianGoal(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bosses = await ref.read(currentFamilyBossesProvider.future);
    Boss? activeBoss;
    for (final boss in bosses) {
      if (boss.isActive) {
        activeBoss = boss;
        break;
      }
    }
    if (!context.mounted) return;

    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (_) => _ReviewDialog(activeBoss: activeBoss),
    );
    if (result == null || !context.mounted) return;

    final success = await ref
        .read(rewardSuggestionsControllerProvider.notifier)
        .createGuardianGoal(
          title: result.title,
          description: result.description,
          questCount: result.questCount,
          boss: _bossPayload(result),
          replaceActiveBoss: result.replaceActiveBoss,
        );
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success,
      'Nouvel objectif de récompense lancé pour le Royaume.',
    );
  }

  Future<void> _deliverReward(
    BuildContext context,
    WidgetRef ref,
    RewardSuggestion suggestion,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la remise ?'),
        content: Text(
          'La récompense « ${suggestion.guardianTitle ?? suggestion.title} » '
          'a-t-elle bien été remise au Royaume ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Pas encore'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.redeem),
            label: const Text('Récompense remise'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(rewardSuggestionsControllerProvider.notifier)
        .deliverCollectiveReward(suggestion.id);
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success,
      'Récompense remise et ajoutée aux Chroniques du Royaume.',
    );
  }

  Future<void> _editReward(
    BuildContext context,
    WidgetRef ref,
    RewardSuggestion suggestion,
  ) async {
    final draft = await showDialog<_RewardEditDraft>(
      context: context,
      builder: (_) => _RewardEditDialog(suggestion: suggestion),
    );
    if (draft == null || !context.mounted) return;

    final success = await ref
        .read(rewardSuggestionsControllerProvider.notifier)
        .updateCollectiveReward(
          suggestionId: suggestion.id,
          title: draft.title,
          description: draft.description,
          questCount: draft.questCount,
        );
    if (!context.mounted) return;
    _showResult(context, ref, success, 'Récompense mise à jour.');
  }

  Future<void> _archiveReward(
    BuildContext context,
    WidgetRef ref,
    RewardSuggestion suggestion,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archiver cette récompense ?'),
        content: Text(
          '« ${suggestion.guardianTitle ?? suggestion.title} » quittera les '
          'objectifs actifs mais restera dans le Carnet des légendes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(rewardSuggestionsControllerProvider.notifier)
        .archiveCollectiveReward(suggestion.id);
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success,
      'Récompense archivée dans le Carnet des légendes.',
    );
  }

  Future<void> _moveReward(
    BuildContext context,
    WidgetRef ref,
    List<RewardSuggestion> queue,
    RewardSuggestion suggestion,
    int offset,
  ) async {
    final currentIndex = queue.indexWhere((item) => item.id == suggestion.id);
    final targetIndex = currentIndex + offset;
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= queue.length) {
      return;
    }

    final reordered = List<RewardSuggestion>.of(queue);
    final moved = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, moved);

    final success = await ref
        .read(rewardSuggestionsControllerProvider.notifier)
        .reorderCollectiveRewards(
          reordered.map((reward) => reward.id).toList(),
        );
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success,
      'Ordre des récompenses mis à jour.',
    );
  }

  Map<String, dynamic>? _bossPayload(_ReviewDraft result) {
    if (result.existingBoss != null) {
      return {
        'existing_boss_id': result.existingBoss!.id,
        'name': result.existingBoss!.name,
      };
    }
    if (result.boss == null) return null;
    return {
      'name': result.boss!.fullName,
      'emoji': result.boss!.emoji,
      'element': result.boss!.element,
      'domain_label': result.boss!.domainLabel,
      'description': result.boss!.description,
      'max_hp': result.boss!.maxHp,
      'difficulty': result.boss!.difficulty,
      'required_level': result.boss!.requiredLevel,
      'xp_reward': result.boss!.xpReward,
      'special_item': result.boss!.specialItem,
      'skill_rewards':
          result.boss!.skillRewards.map((reward) => reward.toRpcMap()).toList(),
    };
  }

  void _showResult(
    BuildContext context,
    WidgetRef ref,
    bool success,
    String successMessage,
  ) {
    final error = ref.read(rewardSuggestionsControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : 'Impossible : $error'),
      ),
    );
  }
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard({required this.isGuardian});

  final bool isGuardian;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 42)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGuardian ? 'Conseil des Gardiens' : 'Formuler un souhait',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isGuardian
                        ? 'Créez plusieurs récompenses, puis choisissez '
                            'celle qui recevra les prochaines quêtes validées.'
                        : 'Suggérez une récompense et un nombre de quêtes. '
                            'Les Gardiens restent seuls décisionnaires.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityExplanationCard extends StatelessWidget {
  const _PriorityExplanationCard({required this.isGuardian});

  final bool isGuardian;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.low_priority),
        title: const Text('File des récompenses'),
        subtitle: Text(
          isGuardian
              ? 'La prochaine quête validée progressera sur la priorité 1. '
                  'Utilisez les flèches pour changer de cible sans perdre '
                  'la progression déjà acquise.'
              : 'Les quêtes validées progressent sur la priorité 1, puis '
                  'basculent automatiquement vers la suivante.',
        ),
      ),
    );
  }
}

class _RewardSectionTitle extends StatelessWidget {
  const _RewardSectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle case final text?) ...[
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.isGuardian,
    required this.busy,
    required this.onReview,
    required this.onDeliver,
    required this.onEdit,
    required this.onArchive,
    required this.priorityPosition,
    required this.priorityCount,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final RewardSuggestion suggestion;
  final bool isGuardian;
  final bool busy;
  final VoidCallback onReview;
  final VoidCallback onDeliver;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final int? priorityPosition;
  final int priorityCount;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final approved = suggestion.status == 'approved';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(suggestion.statusLabel)),
              ],
            ),
            if (priorityPosition case final position?) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(
                      position == 1 ? Icons.flag : Icons.format_list_numbered,
                      size: 18,
                    ),
                    label: Text(
                      position == 1
                          ? 'Priorité actuelle'
                          : 'Priorité $position',
                    ),
                  ),
                  if (isGuardian) ...[
                    IconButton.filledTonal(
                      tooltip: 'Monter dans les priorités',
                      onPressed: !busy && position > 1 ? onMoveUp : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Descendre dans les priorités',
                      onPressed:
                          !busy && position < priorityCount ? onMoveDown : null,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ],
              ),
            ],
            Text(
              '${suggestion.createdByGuardian ? 'Objectif fixé par les Gardiens' : 'Proposé par ${suggestion.proposerName}'} · '
              '${DateFormat('dd/MM/yyyy').format(suggestion.createdAt.toLocal())}',
            ),
            if (suggestion.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(suggestion.description),
            ],
            const SizedBox(height: 10),
            if (!suggestion.createdByGuardian)
              Text('Souhait : ${suggestion.suggestedQuestCount} quêtes'),
            if (approved) ...[
              const Divider(height: 28),
              Text(
                suggestion.guardianTitle ?? suggestion.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (suggestion.guardianQuestCount case final questCount?) ...[
                Text(
                  'Progression collective : '
                  '${suggestion.completedQuestCount}/$questCount quêtes',
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: questCount == 0
                      ? 0
                      : (suggestion.completedQuestCount / questCount)
                          .clamp(0, 1),
                ),
              ],
              if (suggestion.guardianBossTheme case final bossName?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Boss invoqué : $bossName'),
                ),
              if (suggestion.isDelivered)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Chip(
                    avatar: Icon(Icons.redeem, size: 18),
                    label: Text('Récompense remise'),
                  ),
                )
              else if (suggestion.isFulfilled)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      const Chip(
                        avatar: Icon(Icons.celebration, size: 18),
                        label: Text('Récompense débloquée !'),
                      ),
                      if (isGuardian)
                        FilledButton.icon(
                          onPressed: busy ? null : onDeliver,
                          icon: const Icon(Icons.redeem),
                          label: const Text('Confirmer la remise'),
                        ),
                    ],
                  ),
                ),
            ],
            if (isGuardian && suggestion.status == 'pending') ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: busy ? null : onReview,
                icon: const Icon(Icons.gavel),
                label: const Text('Examiner'),
              ),
            ],
            if (isGuardian &&
                suggestion.status == 'approved' &&
                !suggestion.isArchived) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (!suggestion.isDelivered)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier'),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onArchive,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archiver'),
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

class _RewardEditDialog extends StatefulWidget {
  const _RewardEditDialog({required this.suggestion});

  final RewardSuggestion suggestion;

  @override
  State<_RewardEditDialog> createState() => _RewardEditDialogState();
}

class _RewardEditDialogState extends State<_RewardEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late bool _useQuestGoal;
  late int _questCount;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.suggestion.guardianTitle ?? widget.suggestion.title,
    );
    _description = TextEditingController(
      text: widget.suggestion.guardianDescription ??
          widget.suggestion.description,
    );
    _useQuestGoal = widget.suggestion.guardianQuestCount != null;
    _questCount = widget.suggestion.guardianQuestCount ??
        widget.suggestion.completedQuestCount.clamp(1, 100).toInt();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minimum = widget.suggestion.completedQuestCount.clamp(1, 100).toInt();
    final canRemoveQuestGoal = widget.suggestion.bossId != null;

    return AlertDialog(
      title: const Text('Modifier la récompense'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Nom de la récompense',
                ),
              ),
              TextField(
                controller: _description,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description et conditions',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _useQuestGoal,
                onChanged: canRemoveQuestGoal
                    ? (value) => setState(() => _useQuestGoal = value)
                    : null,
                title: const Text('Objectif de quêtes'),
                subtitle: Text(
                  canRemoveQuestGoal
                      ? 'Le boss associé reste inchangé.'
                      : 'Obligatoire car aucun boss n’est associé.',
                ),
              ),
              if (_useQuestGoal)
                Row(
                  children: [
                    const Expanded(child: Text('Quêtes nécessaires')),
                    IconButton(
                      onPressed: _questCount > minimum
                          ? () => setState(() => _questCount--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_questCount'),
                    IconButton(
                      onPressed: _questCount < 100
                          ? () => setState(() => _questCount++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }

  void _save() {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Donnez un nom à la récompense.');
      return;
    }
    if (_useQuestGoal && _questCount < widget.suggestion.completedQuestCount) {
      setState(
        () => _error = 'Le nouvel objectif ne peut pas être inférieur à la '
            'progression actuelle.',
      );
      return;
    }

    Navigator.pop(
      context,
      _RewardEditDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        questCount: _useQuestGoal ? _questCount : null,
      ),
    );
  }
}

class _RewardEditDraft {
  const _RewardEditDraft({
    required this.title,
    required this.description,
    required this.questCount,
  });

  final String title;
  final String description;
  final int? questCount;
}

class _RewardDraftDialog extends StatefulWidget {
  const _RewardDraftDialog();

  @override
  State<_RewardDraftDialog> createState() => _RewardDraftDialogState();
}

class _RewardDraftDialogState extends State<_RewardDraftDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  int _questCount = 5;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau souhait'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Récompense souhaitée',
                hintText: 'Ex. Choisir le film du samedi',
              ),
            ),
            TextField(
              controller: _description,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Pourquoi ?'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Nombre de quêtes suggéré')),
                IconButton(
                  onPressed: _questCount > 1
                      ? () => setState(() => _questCount--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_questCount'),
                IconButton(
                  onPressed: _questCount < 100
                      ? () => setState(() => _questCount++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().length < 2) return;
            Navigator.pop(
              context,
              _RewardDraft(
                title: _title.text.trim(),
                description: _description.text.trim(),
                questCount: _questCount,
              ),
            );
          },
          child: const Text('Envoyer aux Gardiens'),
        ),
      ],
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    this.suggestion,
    this.activeBoss,
  });

  final RewardSuggestion? suggestion;
  final Boss? activeBoss;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late int _questCount;
  bool _useQuestGoal = true;
  bool _useBoss = false;
  bool _attachActiveBoss = false;
  bool _replaceActiveBoss = false;
  BossSuggestion? _selectedBoss;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.suggestion?.title ?? '');
    _description =
        TextEditingController(text: widget.suggestion?.description ?? '');
    _questCount = widget.suggestion?.suggestedQuestCount ?? 10;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.suggestion == null
            ? 'Créer une récompense du Royaume'
            : 'Souhait collectif de ${widget.suggestion!.proposerName}',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Récompense collective finale',
                ),
              ),
              TextField(
                controller: _description,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Conditions'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Objectif de quêtes'),
                subtitle: const Text(
                  'La récompense progressera lorsque son tour arrivera dans '
                  'la file de priorité.',
                ),
                value: _useQuestGoal,
                onChanged: (value) => setState(() => _useQuestGoal = value),
              ),
              if (_useQuestGoal)
                Row(
                  children: [
                    const Expanded(child: Text('Quêtes nécessaires')),
                    IconButton(
                      onPressed: _questCount > 1
                          ? () => setState(() => _questCount--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_questCount'),
                    IconButton(
                      onPressed: _questCount < 100
                          ? () => setState(() => _questCount++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Invoquer un boss'),
                subtitle: const Text(
                  'Le souhait ne sera accompli qu’après sa défaite.',
                ),
                value: _useBoss,
                onChanged: (value) => setState(() {
                  _useBoss = value;
                  _attachActiveBoss = value && widget.activeBoss != null;
                  if (!value) {
                    _selectedBoss = null;
                    _replaceActiveBoss = false;
                  }
                }),
              ),
              if (_useBoss) ...[
                if (widget.activeBoss != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Rattacher au boss actif : ${widget.activeBoss!.name}',
                    ),
                    subtitle: const Text(
                      'Plusieurs récompenses peuvent dépendre du même combat.',
                    ),
                    value: _attachActiveBoss,
                    onChanged: (value) => setState(() {
                      _attachActiveBoss = value;
                      if (value) {
                        _selectedBoss = null;
                        _replaceActiveBoss = false;
                      }
                    }),
                  ),
                if (!_attachActiveBoss)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _chooseBoss,
                      icon: const Icon(Icons.menu_book),
                      label: Text(
                        _selectedBoss == null
                            ? 'Choisir dans le bestiaire'
                            : '${_selectedBoss!.emoji} ${_selectedBoss!.fullName}',
                      ),
                    ),
                  ),
                if (widget.activeBoss != null && !_attachActiveBoss)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remplacer le boss actuellement actif'),
                    subtitle: const Text(
                      'Le boss actuel sera retiré avant l’invocation.',
                    ),
                    value: _replaceActiveBoss,
                    onChanged: (value) => setState(
                      () => _replaceActiveBoss = value ?? false,
                    ),
                  ),
              ],
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _validationError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        if (widget.suggestion != null)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _ReviewDraft(
                status: 'rejected',
                title: _title.text.trim(),
                description: _description.text.trim(),
                questCount: null,
                boss: null,
                existingBoss: null,
                replaceActiveBoss: false,
              ),
            ),
            child: const Text('Refuser'),
          ),
        FilledButton.icon(
          onPressed: _approve,
          icon: const Icon(Icons.check),
          label: const Text('Valider et lancer'),
        ),
      ],
    );
  }

  Future<void> _chooseBoss() async {
    final boss = await showDialog<BossSuggestion>(
      context: context,
      builder: (_) => const BossSuggestionsDialog(),
    );
    if (boss == null || !mounted) return;
    setState(() {
      _selectedBoss = boss;
      _validationError = null;
    });
  }

  void _approve() {
    String? error;
    if (_title.text.trim().length < 2) {
      error = 'Donnez un nom à la récompense collective.';
    } else if (!_useQuestGoal && !_useBoss) {
      error = 'Choisissez un nombre de quêtes, un boss, ou les deux.';
    } else if (_useBoss && !_attachActiveBoss && _selectedBoss == null) {
      error = 'Choisissez le boss à invoquer dans le bestiaire.';
    } else if (_useBoss &&
        !_attachActiveBoss &&
        widget.activeBoss != null &&
        !_replaceActiveBoss) {
      error =
          'Un boss est déjà actif. Autorisez son remplacement ou retirez-le.';
    }

    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    Navigator.pop(
      context,
      _ReviewDraft(
        status: 'approved',
        title: _title.text.trim(),
        description: _description.text.trim(),
        questCount: _useQuestGoal ? _questCount : null,
        boss: _useBoss && !_attachActiveBoss ? _selectedBoss : null,
        existingBoss: _useBoss && _attachActiveBoss ? widget.activeBoss : null,
        replaceActiveBoss: _replaceActiveBoss,
      ),
    );
  }
}

class _RewardDraft {
  const _RewardDraft({
    required this.title,
    required this.description,
    required this.questCount,
  });

  final String title;
  final String description;
  final int questCount;
}

class _ReviewDraft {
  const _ReviewDraft({
    required this.status,
    required this.title,
    required this.description,
    required this.questCount,
    required this.boss,
    required this.existingBoss,
    required this.replaceActiveBoss,
  });

  final String status;
  final String title;
  final String description;
  final int? questCount;
  final BossSuggestion? boss;
  final Boss? existingBoss;
  final bool replaceActiveBoss;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Impossible de charger les souhaits : $error'),
      ),
    );
  }
}
