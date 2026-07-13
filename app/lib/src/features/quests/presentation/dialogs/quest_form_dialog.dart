import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/domains_provider.dart';
import '../../domain/quest.dart';
import '../../providers/quests_provider.dart';

class QuestFormDialog extends ConsumerStatefulWidget {
  const QuestFormDialog({super.key, this.quest});

  final Quest? quest;

  bool get isEditing => quest != null;

  @override
  ConsumerState<QuestFormDialog> createState() => _QuestFormDialogState();
}

class _QuestFormDialogState extends ConsumerState<QuestFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _realTaskController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _xpController;
  late final TextEditingController _goldController;
  late final TextEditingController _bossDamageController;

  String _frequency = 'once';
  String? _domainId;

  @override
  void initState() {
    super.initState();

    final quest = widget.quest;

    _titleController = TextEditingController(text: quest?.title ?? '');
    _realTaskController = TextEditingController(text: quest?.realTask ?? '');
    _descriptionController = TextEditingController(text: quest?.description ?? '');
    _xpController = TextEditingController(text: '${quest?.xpReward ?? 10}');
    _goldController = TextEditingController(text: '${quest?.goldReward ?? 5}');
    _bossDamageController =
        TextEditingController(text: '${quest?.bossDamage ?? 5}');

    _frequency = quest?.frequency ?? 'once';
    _domainId = quest?.domainId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _realTaskController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    _goldController.dispose();
    _bossDamageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domainsAsync = ref.watch(currentFamilyDomainsProvider);
    final createState = ref.watch(createQuestControllerProvider);
    final updateState = ref.watch(updateQuestControllerProvider);

    final isLoading = createState.isLoading || updateState.isLoading;

    return AlertDialog(
      title: Text(widget.isEditing ? 'Modifier la mission' : 'Nouvelle mission'),
      content: SizedBox(
        width: 520,
        child: domainsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text('Erreur domaines : $error'),
          data: (domains) {
            if (domains.isEmpty) {
              return const Text('Aucun domaine disponible.');
            }

            _domainId ??= domains.first.id;

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la mission',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _realTaskController,
                      decoration: const InputDecoration(
                        labelText: 'Tâche réelle',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _domainId,
                      decoration: const InputDecoration(labelText: 'Domaine'),
                      items: domains
                          .map(
                            (domain) => DropdownMenuItem(
                              value: domain.id,
                              child: Text(domain.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _domainId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: 'Fréquence'),
                      items: const [
                        DropdownMenuItem(value: 'once', child: Text('Une fois')),
                        DropdownMenuItem(value: 'daily', child: Text('Quotidienne')),
                        DropdownMenuItem(value: 'weekly', child: Text('Hebdomadaire')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _frequency = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _xpController,
                            decoration: const InputDecoration(labelText: 'XP'),
                            keyboardType: TextInputType.number,
                            validator: _positiveInt,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _goldController,
                            decoration: const InputDecoration(labelText: 'Or'),
                            keyboardType: TextInputType.number,
                            validator: _positiveInt,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _bossDamageController,
                            decoration: const InputDecoration(
                              labelText: 'Dégâts',
                            ),
                            keyboardType: TextInputType.number,
                            validator: _positiveInt,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: Text(widget.isEditing ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Champ obligatoire';
    }
    return null;
  }

  String? _positiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 0) {
      return 'Nombre invalide';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_domainId == null) return;

    if (widget.isEditing) {
      await ref.read(updateQuestControllerProvider.notifier).updateQuest(
            questId: widget.quest!.id,
            title: _titleController.text.trim(),
            realTask: _realTaskController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            domainId: _domainId!,
            xpReward: int.parse(_xpController.text),
            goldReward: int.parse(_goldController.text),
            bossDamage: int.parse(_bossDamageController.text),
            frequency: _frequency,
          );
    } else {
      await ref.read(createQuestControllerProvider.notifier).createQuest(
            title: _titleController.text.trim(),
            realTask: _realTaskController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            domainId: _domainId!,
            xpReward: int.parse(_xpController.text),
            goldReward: int.parse(_goldController.text),
            bossDamage: int.parse(_bossDamageController.text),
            frequency: _frequency,
          );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}