import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../profile/providers/rpg_profile_provider.dart';
import '../domain/reward_suggestion.dart';
import '../providers/reward_suggestions_provider.dart';

class RewardSuggestionsPage extends ConsumerWidget {
  const RewardSuggestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentRpgProfileProvider);
    final suggestionsAsync = ref.watch(currentRewardSuggestionsProvider);
    final busy = ref.watch(rewardSuggestionsControllerProvider).isLoading;

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
        data: (profile) => profile.role == 'guardian'
            ? null
            : FloatingActionButton.extended(
                onPressed: busy ? null : () => _proposeReward(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Faire un souhait'),
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
  ) async {
    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (_) => _ReviewDialog(suggestion: suggestion),
    );
    if (result == null || !context.mounted) return;

    final success =
        await ref.read(rewardSuggestionsControllerProvider.notifier).review(
              suggestionId: suggestion.id,
              status: result.status,
              title: result.title,
              description: result.description,
              questCount: result.questCount,
              bossTheme: result.bossTheme,
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
                        ? 'Examinez les souhaits, adaptez leur objectif et '
                            'choisissez le boss qui protégera la récompense.'
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
              'Proposé par ${suggestion.proposerName} · '
              '${DateFormat('dd/MM/yyyy').format(suggestion.createdAt.toLocal())}',
            ),
            if (suggestion.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(suggestion.description),
            ],
            const SizedBox(height: 10),
            Text('Souhait : ${suggestion.suggestedQuestCount} quêtes'),
            if (approved) ...[
              const Divider(height: 28),
              Text(
                suggestion.guardianTitle ?? suggestion.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${suggestion.guardianQuestCount ?? suggestion.suggestedQuestCount} '
                'quêtes · Boss : ${suggestion.guardianBossTheme}',
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
  const _ReviewDialog({required this.suggestion});

  final RewardSuggestion suggestion;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _bossTheme = TextEditingController();
  late int _questCount;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.suggestion.title);
    _description = TextEditingController(text: widget.suggestion.description);
    _questCount = widget.suggestion.suggestedQuestCount;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _bossTheme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Souhait de ${widget.suggestion.proposerName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                maxLength: 80,
                decoration:
                    const InputDecoration(labelText: 'Récompense finale'),
              ),
              TextField(
                controller: _description,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Conditions'),
              ),
              TextField(
                controller: _bossTheme,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Boss associé',
                  hintText: 'Ex. Dragon des Chaussettes',
                ),
              ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _ReviewDraft(
              status: 'rejected',
              title: _title.text.trim(),
              description: _description.text.trim(),
              questCount: _questCount,
              bossTheme: '',
            ),
          ),
          child: const Text('Refuser'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().length < 2 ||
                _bossTheme.text.trim().length < 2) {
              return;
            }
            Navigator.pop(
              context,
              _ReviewDraft(
                status: 'approved',
                title: _title.text.trim(),
                description: _description.text.trim(),
                questCount: _questCount,
                bossTheme: _bossTheme.text.trim(),
              ),
            );
          },
          child: const Text('Approuver'),
        ),
      ],
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

class _ReviewDraft extends _RewardDraft {
  const _ReviewDraft({
    required this.status,
    required super.title,
    required super.description,
    required super.questCount,
    required this.bossTheme,
  });

  final String status;
  final String bossTheme;
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
