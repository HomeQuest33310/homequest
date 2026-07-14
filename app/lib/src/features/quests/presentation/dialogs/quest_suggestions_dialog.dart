import 'package:flutter/material.dart';

import '../../domain/quest_suggestion.dart';

class QuestSuggestionsDialog extends StatefulWidget {
  const QuestSuggestionsDialog({super.key});

  @override
  State<QuestSuggestionsDialog> createState() => _QuestSuggestionsDialogState();
}

class _QuestSuggestionsDialogState extends State<QuestSuggestionsDialog> {
  late final Future<List<QuestSuggestion>> _catalog;
  String _query = '';
  String? _locationKey;
  int? _difficulty;

  @override
  void initState() {
    super.initState();
    _catalog = QuestSuggestionCatalog.load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grimoire des quêtes héroïques'),
      content: SizedBox(
        width: 760,
        height: 620,
        child: FutureBuilder<List<QuestSuggestion>>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child:
                    Text('Impossible de lire le grimoire : ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allSuggestions = snapshot.data!;
            final locations = <String, String>{
              for (final suggestion in allSuggestions)
                suggestion.locationKey: suggestion.locationLabel,
            };
            final filtered = allSuggestions.where((suggestion) {
              final query = _query.toLowerCase();
              final matchesQuery = query.isEmpty ||
                  suggestion.realTask.toLowerCase().contains(query) ||
                  suggestion.heroicTitle.toLowerCase().contains(query) ||
                  suggestion.skills.any(
                    (skill) => skill.name.toLowerCase().contains(query),
                  );
              return matchesQuery &&
                  (_locationKey == null ||
                      suggestion.locationKey == _locationKey) &&
                  (_difficulty == null || suggestion.difficulty == _difficulty);
            }).toList();

            return Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Rechercher une tâche ou une quête',
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _locationKey,
                        decoration: const InputDecoration(labelText: 'Lieu'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tous les lieux'),
                          ),
                          ...locations.entries.map(
                            (entry) => DropdownMenuItem<String?>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _locationKey = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _difficulty,
                        decoration:
                            const InputDecoration(labelText: 'Difficulté'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Toutes les difficultés'),
                          ),
                          for (var level = 1; level <= 5; level++)
                            DropdownMenuItem<int?>(
                              value: level,
                              child: Text(List.filled(level, '⭐').join()),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _difficulty = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${filtered.length} propositions'),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('Aucune quête ne correspond.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final suggestion = filtered[index];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: Text(
                                  suggestion.emoji,
                                  style: const TextStyle(fontSize: 30),
                                ),
                                title: Text(suggestion.heroicTitle),
                                subtitle: Text(
                                  '${suggestion.realTask} · '
                                  '${suggestion.locationLabel} · '
                                  '${suggestion.element}\n'
                                  '${suggestion.skills.map((skill) => '${skill.icon} ${skill.name}').join(' · ')}',
                                ),
                                isThreeLine: true,
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${suggestion.xpReward} XP'),
                                    Text(
                                      List.filled(suggestion.difficulty, '⭐')
                                          .join(),
                                    ),
                                  ],
                                ),
                                onTap: () =>
                                    Navigator.of(context).pop(suggestion),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
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
