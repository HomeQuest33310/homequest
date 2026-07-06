import 'package:flutter/material.dart';

import '../domain/quest.dart';

const demoQuests = [
  Quest(
    id: 'q1',
    title: 'Nettoyer les cuisines royales',
    realTask: 'Faire la vaisselle',
    xpReward: 20,
    goldReward: 10,
    bossDamage: 15,
    skillRewards: {'Cuisine': 5, 'Organisation': 2},
  ),
  Quest(
    id: 'q2',
    title: 'Chasser les monstres de poussière',
    realTask: 'Passer l’aspirateur',
    xpReward: 30,
    goldReward: 10,
    bossDamage: 20,
    skillRewards: {'Organisation': 5, 'Endurance': 2},
  ),
];

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quêtes')),
      body: ListView.builder(
        itemCount: demoQuests.length,
        itemBuilder: (context, index) => _QuestCard(quest: demoQuests[index]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle quête'),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quest.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Tâche réelle : ${quest.realTask}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('+${quest.xpReward} XP')),
                Chip(label: Text('+${quest.goldReward} or')),
                Chip(label: Text('${quest.bossDamage} dégâts')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Compétences : ${quest.skillRewards.keys.join(', ')}'),
          ],
        ),
      ),
    );
  }
}
