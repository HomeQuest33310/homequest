import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/kingdom_legend_entry.dart';
import '../providers/chronicles_provider.dart';

class KingdomLegendPage extends ConsumerStatefulWidget {
  const KingdomLegendPage({super.key});

  @override
  ConsumerState<KingdomLegendPage> createState() => _KingdomLegendPageState();
}

class _KingdomLegendPageState extends ConsumerState<KingdomLegendPage> {
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final legendAsync = ref.watch(kingdomLegendProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour au Royaume',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Carnet des légendes'),
        actions: [
          IconButton(
            tooltip: 'Actualiser le carnet',
            onPressed: () => ref.invalidate(kingdomLegendProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: legendAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Impossible d’ouvrir le Carnet : $error'),
          ),
        ),
        data: (entries) {
          final filtered = _category == 'all'
              ? entries
              : entries.where((entry) => entry.category == _category).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(kingdomLegendProvider);
              await ref.read(kingdomLegendProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _LegendHeader(
                    entries: entries,
                    selectedCategory: _category,
                    onCategoryChanged: (category) {
                      setState(() => _category = category);
                    },
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Aucune légende dans cette catégorie.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _LegendCard(entry: filtered[index]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegendHeader extends StatelessWidget {
  const _LegendHeader({
    required this.entries,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final List<KingdomLegendEntry> entries;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    const categories = <(String, String, IconData)>[
      ('all', 'Tout', Icons.auto_stories),
      ('member', 'Héros', Icons.groups),
      ('invitation', 'Invitations', Icons.mark_email_read_outlined),
      ('quest', 'Quêtes', Icons.assignment_turned_in_outlined),
      ('boss', 'Boss', Icons.local_fire_department_outlined),
      ('reward', 'Récompenses', Icons.redeem),
      ('chronicle', 'Royaume', Icons.castle_outlined),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  const Text('📖', style: TextStyle(fontSize: 46)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'La mémoire vivante du Royaume',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${entries.length} événements : arrivées de héros, '
                          'quêtes, victoires, boss et récompenses.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selectedCategory == category.$1,
                      onSelected: (_) => onCategoryChanged(category.$1),
                      avatar: Icon(category.$3, size: 18),
                      label: Text(category.$2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({required this.entry});

  final KingdomLegendEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = _presentation(entry.category);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: presentation.$3,
              child: Icon(presentation.$2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(_statusLabel(entry.status)),
                      ),
                    ],
                  ),
                  if (entry.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(entry.body),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${presentation.$1} · '
                    '${DateFormat('dd/MM/yyyy à HH:mm').format(entry.occurredAt.toLocal())}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, IconData, Color) _presentation(String category) {
    switch (category) {
      case 'member':
        return ('Héros', Icons.person_add_alt_1, Colors.blue.shade100);
      case 'invitation':
        return ('Invitation', Icons.mail_outline, Colors.cyan.shade100);
      case 'quest':
        return ('Quête', Icons.assignment_turned_in, Colors.amber.shade100);
      case 'boss':
        return ('Boss', Icons.local_fire_department, Colors.red.shade100);
      case 'reward':
        return ('Récompense', Icons.redeem, Colors.green.shade100);
      default:
        return ('Royaume', Icons.auto_stories, Colors.purple.shade100);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Actif';
      case 'inactive':
        return 'Inactif';
      case 'pending':
        return 'En attente';
      case 'approved':
        return 'Validé';
      case 'rejected':
        return 'Refusé';
      case 'defeated':
        return 'Vaincu';
      case 'unlocked':
        return 'Débloquée';
      case 'delivered':
        return 'Remise';
      case 'archived':
        return 'Archivée';
      case 'cancelled':
        return 'Annulée';
      case 'expired':
        return 'Expirée';
      default:
        return 'Inscrit';
    }
  }
}
