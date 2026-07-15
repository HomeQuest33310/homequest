import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/domain/domain.dart';
import '../../../domains/providers/domains_provider.dart';
import '../../../kingdom/domain/kingdom.dart';
import '../../../kingdom/providers/kingdom_provider.dart';
import '../../domain/quest_suggestion.dart';
import '../../providers/voluntary_quest_requests_provider.dart';
import 'quest_suggestions_dialog.dart';

class VoluntaryQuestRequestDialog extends ConsumerStatefulWidget {
  const VoluntaryQuestRequestDialog({super.key});

  @override
  ConsumerState<VoluntaryQuestRequestDialog> createState() =>
      _VoluntaryQuestRequestDialogState();
}

class _VoluntaryQuestRequestDialogState
    extends ConsumerState<VoluntaryQuestRequestDialog> {
  final _noteController = TextEditingController();
  QuestSuggestion? _suggestion;
  String? _domainId;
  bool _alreadyCompleted = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domainsAsync = ref.watch(currentFamilyDomainsProvider);
    final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
    final action = ref.watch(voluntaryQuestRequestsControllerProvider);

    return AlertDialog(
      title: const Text('Je voudrais accomplir une quête'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choisissez une initiative utile au Royaume. Le Conseil des '
                'Gardiens devra l’approuver.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: action.isLoading ? null : _chooseFromCatalog,
                icon: const Icon(Icons.auto_stories),
                label: Text(
                  _suggestion == null
                      ? 'Choisir dans le catalogue'
                      : 'Changer de quête',
                ),
              ),
              if (_suggestion != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_suggestion!.emoji} ${_suggestion!.heroicTitle}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(_suggestion!.realTask),
                        const SizedBox(height: 8),
                        Text(
                          '${_suggestion!.xpReward} XP · '
                          '${_suggestion!.goldReward} or · '
                          '${_suggestion!.bossDamage} dégâts',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              domainsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Domaines indisponibles : $error'),
                data: (domains) {
                  final allowed = _allowedDomains(domains, kingdom);
                  if (allowed.isEmpty) {
                    return const Text('Aucun Domaine accessible.');
                  }
                  _domainId ??= allowed.first.id;
                  if (!allowed.any((domain) => domain.id == _domainId)) {
                    _domainId = allowed.first.id;
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _domainId,
                    decoration: const InputDecoration(
                      labelText: 'Domaine concerné',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    items: [
                      for (final domain in allowed)
                        DropdownMenuItem(
                          value: domain.id,
                          child: Text('${domain.icon} ${domain.name}'),
                        ),
                    ],
                    onChanged: action.isLoading
                        ? null
                        : (value) => setState(() => _domainId = value),
                  );
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _alreadyCompleted,
                title: const Text('Je l’ai déjà accomplie'),
                subtitle: Text(
                  _alreadyCompleted
                      ? 'Le Gardien validera l’initiative après sa réalisation.'
                      : 'Après accord, elle apparaîtra dans vos missions.',
                ),
                onChanged: action.isLoading
                    ? null
                    : (value) => setState(() => _alreadyCompleted = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                enabled: !action.isLoading,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message au Conseil (facultatif)',
                  hintText: 'Pourquoi cette quête aidera-t-elle le Royaume ?',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: action.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: action.isLoading ? null : _submit,
          icon: action.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.campaign),
          label: const Text('Soumettre au Conseil'),
        ),
      ],
    );
  }

  List<Domain> _allowedDomains(List<Domain> domains, Kingdom? kingdom) {
    if (kingdom?.membershipRole == 'mercenary' &&
        kingdom?.membershipScope == 'domain') {
      return domains
          .where((domain) => domain.id == kingdom?.membershipDomainId)
          .toList();
    }
    return domains;
  }

  Future<void> _chooseFromCatalog() async {
    final suggestion = await showDialog<QuestSuggestion>(
      context: context,
      builder: (_) => const QuestSuggestionsDialog(),
    );
    if (suggestion != null && mounted) {
      setState(() => _suggestion = suggestion);
    }
  }

  Future<void> _submit() async {
    final suggestion = _suggestion;
    final domainId = _domainId;
    if (suggestion == null || domainId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une quête et un Domaine.')),
      );
      return;
    }

    final note = _noteController.text.trim();
    final success = await ref
        .read(voluntaryQuestRequestsControllerProvider.notifier)
        .submit(
          domainId: domainId,
          suggestion: suggestion,
          alreadyCompleted: _alreadyCompleted,
          note: note.isEmpty ? null : note,
        );
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre initiative a été transmise aux Gardiens.'),
        ),
      );
      return;
    }

    final state = ref.read(voluntaryQuestRequestsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Demande impossible : ${state.error}')),
    );
  }
}
