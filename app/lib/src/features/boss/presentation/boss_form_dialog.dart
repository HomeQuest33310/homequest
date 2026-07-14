import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/boss.dart';
import '../domain/boss_suggestion.dart';
import '../providers/boss_provider.dart';
import 'boss_suggestions_dialog.dart';

class BossFormDialog extends ConsumerStatefulWidget {
  const BossFormDialog({super.key, required this.hasActiveBoss});

  final bool hasActiveBoss;

  @override
  ConsumerState<BossFormDialog> createState() => _BossFormDialogState();
}

class _BossFormDialogState extends ConsumerState<BossFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _emoji = TextEditingController(text: '🐉');
  final _element = TextEditingController(text: 'Neutre');
  final _domain = TextEditingController(text: 'Royaume');
  final _description = TextEditingController();
  final _hp = TextEditingController(text: '300');
  final _requiredLevel = TextEditingController(text: '1');
  final _xpReward = TextEditingController(text: '1000');
  final _specialItem = TextEditingController();
  final Map<String, int> _skillPoints = {};
  int _difficulty = 3;

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _element.dispose();
    _domain.dispose();
    _description.dispose();
    _hp.dispose();
    _requiredLevel.dispose();
    _xpReward.dispose();
    _specialItem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bossControllerProvider);
    return AlertDialog(
      title: const Text('Invoquer un boss'),
      content: SizedBox(
        width: 700,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _chooseSuggestion,
                    icon: const Icon(Icons.menu_book),
                    label: const Text(
                      'Choisir parmi les 11 boss du bestiaire',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: _emoji,
                        decoration: const InputDecoration(labelText: 'Emoji'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nom et titre du boss',
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _element,
                        decoration: const InputDecoration(labelText: 'Élément'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _domain,
                        decoration: const InputDecoration(
                            labelText: 'Domaine narratif'),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _numberField(_hp, 'PV', minimum: 1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numberField(
                        _requiredLevel,
                        'Niveau requis',
                        minimum: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numberField(
                        _xpReward,
                        'Récompense XP',
                        minimum: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_difficulty),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _specialItem,
                        decoration:
                            const InputDecoration(labelText: 'Objet spécial'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Compétences de combat · 2 à 6',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in combatSkills)
                      FilterChip(
                        selected: _skillPoints.containsKey(skill.id),
                        avatar: Text(skill.icon),
                        label: Text(skill.name),
                        onSelected: (selected) =>
                            _toggleSkill(skill.id, selected),
                      ),
                  ],
                ),
                if (_skillPoints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._skillPoints.entries.map((entry) {
                    final skill = combatSkills.firstWhere(
                      (item) => item.id == entry.key,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text('${skill.icon} ${skill.name}')),
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              initialValue: '${entry.value}',
                              decoration:
                                  const InputDecoration(labelText: 'Points'),
                              keyboardType: TextInputType.number,
                              validator: (value) => _positive(value, 1),
                              onChanged: (value) {
                                _skillPoints[entry.key] =
                                    int.tryParse(value) ?? entry.value;
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (widget.hasActiveBoss) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Le boss actuellement actif sera retiré lorsque celui-ci sera invoqué.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: state.isLoading ? null : _submit,
          icon: const Icon(Icons.bolt),
          label: const Text('Invoquer'),
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    required int minimum,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (value) => _positive(value, minimum),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Champ requis' : null;
  }

  String? _positive(String? value, int minimum) {
    final number = int.tryParse(value ?? '');
    return number == null || number < minimum ? 'Minimum : $minimum' : null;
  }

  Future<void> _chooseSuggestion() async {
    final suggestion = await showDialog<BossSuggestion>(
      context: context,
      builder: (_) => const BossSuggestionsDialog(),
    );
    if (suggestion == null || !mounted) return;
    setState(() {
      _name.text = suggestion.fullName;
      _emoji.text = suggestion.emoji;
      _element.text = suggestion.element;
      _domain.text = suggestion.domainLabel;
      _description.text = suggestion.description;
      _hp.text = '${suggestion.maxHp}';
      _difficulty = suggestion.difficulty;
      _requiredLevel.text = '${suggestion.requiredLevel}';
      _xpReward.text = '${suggestion.xpReward}';
      _specialItem.text = suggestion.specialItem;
      _skillPoints
        ..clear()
        ..addEntries(
          suggestion.skillRewards.map(
            (reward) => MapEntry(reward.skillId, reward.points),
          ),
        );
    });
  }

  void _toggleSkill(String skillId, bool selected) {
    setState(() {
      if (!selected) {
        _skillPoints.remove(skillId);
      } else if (_skillPoints.length < 6) {
        _skillPoints[skillId] = _difficulty * 15;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Six compétences maximum.')),
        );
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_skillPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez au moins 2 compétences.')),
      );
      return;
    }
    final rewards = _skillPoints.entries.map((entry) {
      final skill = combatSkills.firstWhere((item) => item.id == entry.key);
      return BossSkillReward(
        skillId: skill.id,
        name: skill.name,
        icon: skill.icon,
        points: entry.value,
      );
    }).toList();
    final success = await ref.read(bossControllerProvider.notifier).createBoss(
          name: _name.text.trim(),
          emoji: _emoji.text.trim(),
          element: _element.text.trim(),
          domainLabel: _domain.text.trim(),
          description: _description.text.trim(),
          maxHp: int.parse(_hp.text),
          difficulty: _difficulty,
          requiredLevel: int.parse(_requiredLevel.text),
          xpReward: int.parse(_xpReward.text),
          specialItem: _specialItem.text.trim(),
          skillRewards: rewards,
          replaceActive: widget.hasActiveBoss,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final state = ref.read(bossControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Impossible d’invoquer le boss : ${state.error}')),
      );
    }
  }
}
