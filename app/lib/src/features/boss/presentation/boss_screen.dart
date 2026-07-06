import 'package:flutter/material.dart';

class BossScreen extends StatelessWidget {
  const BossScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const currentHp = 180;
    const maxHp = 300;

    return Scaffold(
      appBar: AppBar(title: const Text('Boss')),
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🐉 Dragon de la Poussière', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: currentHp / maxHp, minHeight: 14),
                  const SizedBox(height: 8),
                  const Text('$currentHp / $maxHp PV restants'),
                  const SizedBox(height: 20),
                  const Text('Chaque quête validée inflige des dégâts au boss.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
