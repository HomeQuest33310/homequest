import 'package:flutter/material.dart';

import '../domain/boss_suggestion.dart';

class BossSuggestionsDialog extends StatefulWidget {
  const BossSuggestionsDialog({super.key});

  @override
  State<BossSuggestionsDialog> createState() => _BossSuggestionsDialogState();
}

class _BossSuggestionsDialogState extends State<BossSuggestionsDialog> {
  String _query = '';
  int? _difficulty;

  @override
  Widget build(BuildContext context) {
    final filtered = bossSuggestions.where((boss) {
      final query = _query.toLowerCase();
      final matchesQuery = query.isEmpty ||
          boss.name.toLowerCase().contains(query) ||
          boss.subtitle.toLowerCase().contains(query) ||
          boss.element.toLowerCase().contains(query) ||
          boss.domainLabel.toLowerCase().contains(query);
      return matchesQuery &&
          (_difficulty == null || boss.difficulty == _difficulty);
    }).toList();

    return AlertDialog(
      title: const Text('Bestiaire des boss héroïques'),
      content: SizedBox(
        width: 780,
        height: 620,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Rechercher un boss, un élément ou un domaine',
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Difficulté'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tous les niveaux'),
                ),
                for (var level = 3; level <= 5; level++)
                  DropdownMenuItem<int?>(
                    value: level,
                    child: Text(List.filled(level, '⭐').join()),
                  ),
              ],
              onChanged: (value) => setState(() => _difficulty = value),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${filtered.length} boss proposés'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final boss = filtered[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Text(
                        boss.emoji,
                        style: const TextStyle(fontSize: 34),
                      ),
                      title: Text(boss.fullName),
                      subtitle: Text(
                        '${boss.element} · ${boss.domainLabel} · '
                        '${boss.maxHp} PV · niveau ${boss.requiredLevel}\n'
                        '${boss.skillRewards.map((skill) => '${skill.icon} ${skill.name}').join(' · ')}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(List.filled(boss.difficulty, '⭐').join()),
                          Text('${boss.xpReward} XP'),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pop(boss),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
