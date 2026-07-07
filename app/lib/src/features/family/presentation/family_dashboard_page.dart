import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chronicles/domain/chronicle.dart';
import '../../chronicles/providers/chronicles_provider.dart';
import '../../domains/providers/domains_provider.dart';
import '../providers/family_provider.dart';

class FamilyDashboardPage extends ConsumerWidget {
  const FamilyDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final domainsAsync = ref.watch(currentFamilyDomainsProvider);
    final chroniclesAsync = ref.watch(recentChroniclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeQuest'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              ref.invalidate(currentFamilyProvider);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Erreur : $error')),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('Aucun royaume trouvé.'));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏰 ${family.kingdomName}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('Guilde familiale : ${family.name}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🌍 Domaines du Royaume',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      domainsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => Text('Erreur : $error'),
                        data: (domains) {
                          if (domains.isEmpty) {
                            return const Text('Aucun domaine pour le moment.');
                          }
                          return Column(
                            children: domains
                                .map(
                                  (domain) => ListTile(
                                    leading: const Icon(Icons.home),
                                    title: Text(domain.name),
                                    subtitle: Text(
                                      domain.isPrimary
                                          ? 'Domaine principal'
                                          : 'Domaine secondaire',
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📜 Chronique du Royaume',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      chroniclesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => Text('Erreur : $error'),
                        data: (chronicles) {
                          if (chronicles.isEmpty) {
                            return const Column(
                              children: [
                                _ChronicleItem(
                                  emoji: '✨',
                                  text: 'Le royaume vient de naître. Les premières quêtes attendent la guilde.',
                                ),
                                _ChronicleItem(
                                  emoji: '⚔️',
                                  text: 'Bientôt, les aventuriers pourront accomplir leurs premières missions.',
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: chronicles.map(_ChronicleTile.new).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChronicleTile extends StatelessWidget {
  const _ChronicleTile(this.chronicle);

  final Chronicle chronicle;

  @override
  Widget build(BuildContext context) {
    return _ChronicleItem(
      emoji: _emojiForType(chronicle.type),
      text: chronicle.body == null || chronicle.body!.isEmpty
          ? chronicle.title
          : '${chronicle.title}\n${chronicle.body}',
    );
  }

  String _emojiForType(String type) {
    switch (type) {
      case 'kingdom_created':
        return '🏰';
      case 'domain_created':
        return '🏠';
      case 'quest_completed':
        return '⚔️';
      case 'boss_defeated':
        return '🐉';
      case 'level_up':
        return '⭐';
      case 'reward_claimed':
        return '🎁';
      case 'mercenary_joined':
        return '🛡️';
      default:
        return '📜';
    }
  }
}

class _ChronicleItem extends StatelessWidget {
  const _ChronicleItem({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
