import 'package:flutter/material.dart';

import '../domain/skill.dart';

const demoSkills = [
  SkillProgress(name: 'Cuisine', icon: '🍳', xp: 140, level: 3),
  SkillProgress(name: 'Organisation', icon: '🧹', xp: 90, level: 2),
  SkillProgress(name: 'Nature', icon: '🌿', xp: 30, level: 1),
  SkillProgress(name: 'Entraide', icon: '❤️', xp: 75, level: 2),
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final harmony = harmonyRankFor(demoSkills);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Emma', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Aventurière · Niveau 3 · 120 or'),
                  const SizedBox(height: 16),
                  Chip(label: Text(harmonyLabel(harmony))),
                ],
              ),
            ),
          ),
          ...demoSkills.map((skill) => Card(
                child: ListTile(
                  leading: Text(skill.icon, style: const TextStyle(fontSize: 28)),
                  title: Text(skill.name),
                  subtitle: LinearProgressIndicator(value: (skill.xp % 100) / 100),
                  trailing: Text('Niv. ${skill.level}'),
                ),
              )),
        ],
      ),
    );
  }
}
