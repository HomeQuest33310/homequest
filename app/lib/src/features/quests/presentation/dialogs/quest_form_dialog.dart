import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domains/providers/domains_provider.dart';
import '../../domain/quest.dart';
import '../../domain/quest_suggestion.dart';
import '../../providers/quests_provider.dart';
import 'quest_suggestions_dialog.dart';

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
  late final TextEditingController _emojiController;
  late final TextEditingController _elementController;
  late final TextEditingController _xpController;
  late final TextEditingController _goldController;
  late final TextEditingController _bossDamageController;

  String _frequency = 'once';
  String _regionKey = 'custom';
  String? _domainId;
  int _difficulty = 1;
  bool _requiresApproval = true;
  DateTime? _availableFrom;
  late final List<String> _selectedSkillIds;

  @override
  void initState() {
    super.initState();
    final quest = widget.quest;
    _titleController = TextEditingController(text: quest?.title ?? '');
    _realTaskController = TextEditingController(text: quest?.realTask ?? '');
    _descriptionController =
        TextEditingController(text: quest?.description ?? '');
    _emojiController = TextEditingController(text: quest?.emoji ?? '📜');
    _elementController =
        TextEditingController(text: quest?.element ?? 'Neutre');
    _xpController = TextEditingController(text: '${quest?.xpReward ?? 30}');
    _goldController = TextEditingController(text: '${quest?.goldReward ?? 5}');
    _bossDamageController =
        TextEditingController(text: '${quest?.bossDamage ?? 5}');
    _frequency = quest?.frequency ?? 'once';
    _regionKey = quest?.regionKey ?? 'custom';
    _domainId = quest?.domainId;
    _difficulty = quest?.difficulty ?? 1;
    _requiresApproval = quest?.requiresApproval ?? true;
    _availableFrom = quest?.availableFrom?.toLocal();
    _selectedSkillIds = quest?.skillRewards
            .map((reward) => reward.skillId)
            .where((id) => heroicSkills.any((skill) => skill.id == id))
            .take(2)
            .toList() ??
        <String>[];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _realTaskController.dispose();
    _descriptionController.dispose();
    _emojiController.dispose();
    _elementController.dispose();
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
      title:
          Text(widget.isEditing ? 'Modifier la mission' : 'Nouvelle mission'),
      content: SizedBox(
        width: 680,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isEditing) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _chooseSuggestion,
                          icon: const Icon(Icons.auto_stories),
                          label: const Text(
                            'Choisir parmi les 90 propositions héroïques',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Nom héroïque de la mission',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _realTaskController,
                      decoration:
                          const InputDecoration(labelText: 'Tâche réelle'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _emojiController,
                            decoration:
                                const InputDecoration(labelText: 'Emoji'),
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _elementController,
                            decoration:
                                const InputDecoration(labelText: 'Élément'),
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('difficulty-$_difficulty'),
                            initialValue: _difficulty,
                            decoration:
                                const InputDecoration(labelText: 'Difficulté'),
                            items: [
                              for (var level = 1; level <= 5; level++)
                                DropdownMenuItem(
                                  value: level,
                                  child: Text(List.filled(level, '⭐').join()),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _difficulty = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('region-$_regionKey'),
                            initialValue: _regionKey,
                            decoration: const InputDecoration(
                              labelText: 'Lieu habituel',
                            ),
                            items: questLocationLabels.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _regionKey = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _domainId,
                            decoration:
                                const InputDecoration(labelText: 'Domaine'),
                            items: domains
                                .map(
                                  (domain) => DropdownMenuItem(
                                    value: domain.id,
                                    child: Text(domain.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _domainId = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('frequency-$_frequency'),
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: 'Fréquence'),
                      items: const [
                        DropdownMenuItem(
                            value: 'once', child: Text('Une fois')),
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('Quotidienne'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Hebdomadaire'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _frequency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _availableFrom != null,
                              title: const Text('Programmer la disponibilité'),
                              subtitle: Text(
                                switch (_frequency) {
                                  'daily' =>
                                    'Cette date fixe la première disponibilité. '
                                        'La quête reviendra ensuite tous les '
                                        'jours à cette heure.',
                                  'weekly' =>
                                    'Cette date fixe la première disponibilité. '
                                        'La quête reviendra ensuite sept jours '
                                        'après chaque réalisation.',
                                  _ =>
                                    'La quête restera visible, mais personne ne '
                                        'pourra la prendre avant cette date.',
                                },
                              ),
                              onChanged: (scheduled) {
                                setState(() {
                                  _availableFrom = scheduled
                                      ? DateTime.now()
                                          .add(const Duration(hours: 1))
                                          .copyWith(second: 0, millisecond: 0)
                                      : null;
                                });
                              },
                            ),
                            if (_availableFrom != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _chooseAvailableDate,
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(_availableFrom!),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _chooseAvailableTime,
                                      icon: const Icon(Icons.schedule),
                                      label: Text(
                                        DateFormat('HH:mm')
                                            .format(_availableFrom!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Disponible le '
                                  '${DateFormat('dd/MM/yyyy à HH:mm').format(_availableFrom!)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _requiresApproval,
                      title: const Text('Validation par un Gardien'),
                      subtitle: Text(
                        _requiresApproval
                            ? 'Les récompenses sont accordées après validation.'
                            : 'Les récompenses sont accordées automatiquement.',
                      ),
                      onChanged: (value) {
                        setState(() => _requiresApproval = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Compétences héroïques · choisissez-en 2',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final skill in heroicSkills)
                          FilterChip(
                            selected: _selectedSkillIds.contains(skill.id),
                            avatar: Text(skill.icon),
                            label: Text(skill.name),
                            onSelected: (selected) =>
                                _toggleSkill(skill.id, selected),
                          ),
                      ],
                    ),
                    if (_selectedSkillIds.length != 2) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Deux compétences sont nécessaires pour créer la quête.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
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
                            decoration:
                                const InputDecoration(labelText: 'Dégâts'),
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

  Future<void> _chooseSuggestion() async {
    final suggestion = await showDialog<QuestSuggestion>(
      context: context,
      builder: (_) => const QuestSuggestionsDialog(),
    );
    if (suggestion == null || !mounted) return;

    setState(() {
      _titleController.text = suggestion.heroicTitle;
      _realTaskController.text = suggestion.realTask;
      _emojiController.text = suggestion.emoji;
      _elementController.text = suggestion.element;
      _xpController.text = '${suggestion.xpReward}';
      _goldController.text = '${suggestion.goldReward}';
      _bossDamageController.text = '${suggestion.bossDamage}';
      _difficulty = suggestion.difficulty;
      _regionKey = suggestion.locationKey;
      _frequency = suggestion.locationKey == 'quick_daily' ? 'daily' : 'once';
      _selectedSkillIds
        ..clear()
        ..addAll(suggestion.skills.map((skill) => skill.id));
    });
  }

  void _toggleSkill(String skillId, bool selected) {
    setState(() {
      if (!selected) {
        _selectedSkillIds.remove(skillId);
      } else if (_selectedSkillIds.length < 2) {
        _selectedSkillIds.add(skillId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deux compétences maximum.')),
        );
      }
    });
  }

  Future<void> _chooseAvailableDate() async {
    final current = _availableFrom;
    if (current == null) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _availableFrom = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.hour,
        current.minute,
      );
    });
  }

  Future<void> _chooseAvailableTime() async {
    final current = _availableFrom;
    if (current == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _availableFrom = DateTime(
        current.year,
        current.month,
        current.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  List<QuestSkillReward> _skillRewards() {
    final points = skillPointsForDifficulty(_difficulty);
    return [
      for (var index = 0; index < _selectedSkillIds.length; index++)
        QuestSkillReward(
          skillId: _selectedSkillIds[index],
          name: heroicSkills
              .firstWhere((skill) => skill.id == _selectedSkillIds[index])
              .name,
          icon: heroicSkills
              .firstWhere((skill) => skill.id == _selectedSkillIds[index])
              .icon,
          xpReward: points[index],
        ),
    ];
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Champ obligatoire';
    return null;
  }

  String? _positiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 0) return 'Nombre invalide';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _domainId == null) return;
    if (_selectedSkillIds.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez exactement 2 compétences.')),
      );
      return;
    }

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
            availableFrom: _availableFrom,
            requiresApproval: _requiresApproval,
            emoji: _emojiController.text.trim(),
            element: _elementController.text.trim(),
            difficulty: _difficulty,
            regionKey: _regionKey,
            skillRewards: _skillRewards(),
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
            availableFrom: _availableFrom,
            emoji: _emojiController.text.trim(),
            element: _elementController.text.trim(),
            difficulty: _difficulty,
            regionKey: _regionKey,
            skillRewards: _skillRewards(),
          );
    }

    if (!mounted) return;
    final state = widget.isEditing
        ? ref.read(updateQuestControllerProvider)
        : ref.read(createQuestControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’enregistrer : ${state.error}')),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }
}
