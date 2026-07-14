import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
        leading: IconButton(
          tooltip: 'Retour au profil',
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back),
        ),
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
          data: (suggestions) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentRewardSuggestionsProvider);
              await ref.read(currentRewardSuggestionsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _IntroductionCard(isGuardian: profile.role == 'guardian'),
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
                  )
                else
                  for (final suggestion in suggestions)
                    _SuggestionCard(
                      suggestion: suggestion,
                      isGuardian: profile.role == 'guardian',
                      busy: busy,
                      onReview: () => _reviewReward(
                        context,
                        ref,
                        suggestion,
                        activeBoss,
                      ),
                    ),
              ],
            ),
          ),
        ),
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
                        ? 'Validez plusieurs souhaits en parallèle ou créez '
                            'directement une récompense officielle avec un '
                            'objectif de quêtes et/ou un boss.'
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

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.isGuardian,
    required this.busy,
    required this.onReview,
  });

  final RewardSuggestion suggestion;
  final bool isGuardian;
  final bool busy;
  final VoidCallback onReview;

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
              if (suggestion.isFulfilled)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Chip(
                    avatar: Icon(Icons.celebration, size: 18),
                    label: Text('Souhait accompli !'),
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
          ],
        ),
      ),
    );
  }
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
                  'Toutes les quêtes validées de la guilde font progresser le souhait.',
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
