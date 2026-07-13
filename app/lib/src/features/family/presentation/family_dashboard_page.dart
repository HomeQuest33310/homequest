import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chronicles/domain/chronicle.dart';
import '../../chronicles/providers/chronicles_provider.dart';
import '../../domains/domain/domain.dart';
import '../../domains/providers/domains_provider.dart';
import '../../quests/domain/quest.dart';
import '../../quests/presentation/dialogs/quest_form_dialog.dart';
import '../../quests/providers/quests_provider.dart';
import '../domain/family.dart' as domain;
import '../providers/family_members_provider.dart';
import '../providers/family_provider.dart';
import '../providers/family_stats_provider.dart';
import '../../quests/presentation/widgets/quest_card.dart';
import '../../quests/presentation/dialogs/assign_quest_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

class FamilyDashboardPage extends ConsumerWidget {
  const FamilyDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final domainsAsync = ref.watch(currentFamilyDomainsProvider);
    final chroniclesAsync = ref.watch(recentChroniclesProvider);
    final statsAsync = ref.watch(currentFamilyStatsProvider);
    final questsAsync = ref.watch(currentFamilyQuestsProvider);
    final currentMember = ref.watch(currentFamilyMemberProvider).asData?.value;
    final canManageQuests = currentMember?.role == 'guardian';

    Future<void> refreshAll() async {
      ref.invalidate(currentFamilyProvider);
      ref.invalidate(currentFamilyDomainsProvider);
      ref.invalidate(recentChroniclesProvider);
      ref.invalidate(currentFamilyStatsProvider);
      ref.invalidate(currentFamilyQuestsProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeQuest'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: refreshAll,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Membres du royaume',
            onPressed: () => context.go('/members'),
            icon: const Icon(Icons.groups),
          ),
          if (kDebugMode)
            IconButton(
              tooltip: 'Developer Tools',
              onPressed: () => context.go('/devtools'),
              icon: const Icon(Icons.bug_report),
            ),
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
        loading: () => const _LoadingDashboard(),
        error: (error, stackTrace) => _DashboardError(
          error: error,
          onRetry: () => ref.invalidate(currentFamilyProvider),
        ),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('Aucun royaume trouvé.'));
          }

          return RefreshIndicator(
            onRefresh: refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroHeader(family: family),
                const SizedBox(height: 16),
                statsAsync.when(
                  loading: () => const _StatsSkeleton(),
                  error: (error, stackTrace) => _SoftErrorCard(
                    title: 'Statistiques indisponibles',
                    error: error,
                  ),
                  data: (stats) => _StatsRow(stats: stats),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '📜 Registre des Quêtes',
                  subtitle:
                      'Transformez les tâches du quotidien en missions héroïques.',
                  action: canManageQuests
                      ? FilledButton.icon(
                          onPressed: () async {
                            final created = await showDialog<bool>(
                              context: context,
                              builder: (_) => const QuestFormDialog(),
                            );
                            if (created == true) await refreshAll();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une quête'),
                        )
                      : null,
                  child: questsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => _InlineError(error: error),
                    data: (quests) => _QuestsList(
                      quests: quests,
                      canManage: canManageQuests,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '📖 Chronique du Royaume',
                  subtitle:
                      'Les premiers souvenirs de votre aventure familiale.',
                  child: chroniclesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => _InlineError(error: error),
                    data: (chronicles) =>
                        _ChroniclesList(chronicles: chronicles),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '🌍 Domaines',
                  subtitle: 'Les lieux où votre guilde vit ses aventures.',
                  child: domainsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => _InlineError(error: error),
                    data: (domains) => _DomainsList(domains: domains),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionCard(
                  title: '⚔️ Prochaine étape',
                  subtitle: 'Sprint 2.3',
                  child: _NextStepPanel(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.family});

  final domain.Family family;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏰 ${family.kingdomName}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guilde familiale : ${family.name}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(label: 'Livre des Chroniques ouvert'),
                _Badge(label: 'Premier Domaine fondé'),
                _Badge(label: 'Registre des Quêtes actif'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final FamilyStats stats;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final cards = [
      _StatCard(icon: '🧙', value: '${stats.memberCount}', label: 'Aventurier'),
      _StatCard(icon: '🌍', value: '${stats.domainCount}', label: 'Domaine'),
      _StatCard(
          icon: '📜', value: '${stats.chronicleCount}', label: 'Chronique'),
    ];

    if (compact) {
      return Column(
        children: cards
            .map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 10), child: card))
            .toList(),
      );
    }

    return Row(
      children: cards
          .map((card) => Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(right: 10), child: card)))
          .toList(),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon, required this.value, required this.label});

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title,
      required this.subtitle,
      required this.child,
      this.action});

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;

                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                );

                if (action == null) return header;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: action!,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: header),
                    const SizedBox(width: 12),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: action!,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuestsList extends ConsumerWidget {
  const _QuestsList({required this.quests, required this.canManage});

  final List<Quest> quests;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quests.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aucune quête pour le moment.'),
          SizedBox(height: 8),
          Text(
              'Créez votre première quête pour ouvrir le registre des missions.'),
        ],
      );
    }

    return Column(
      children: quests
          .map(
            (quest) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: QuestCard(
                quest: quest,
                onSelfAssign: () => _selfAssign(context, ref, quest),
                onEdit: canManage
                    ? () {
                        showDialog(
                          context: context,
                          builder: (_) => QuestFormDialog(quest: quest),
                        );
                      }
                    : null,
                onAssign: canManage
                    ? () {
                        showDialog(
                          context: context,
                          builder: (_) => AssignQuestDialog(quest: quest),
                        );
                      }
                    : null,
                onArchive: canManage
                    ? () async {
                        await ref
                            .read(updateQuestControllerProvider.notifier)
                            .archiveQuest(quest.id);
                      }
                    : null,
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _selfAssign(
    BuildContext context,
    WidgetRef ref,
    Quest quest,
  ) async {
    final success = await ref
        .read(selfAssignQuestControllerProvider.notifier)
        .selfAssignQuest(quest.id);
    if (!context.mounted) return;

    final state = ref.read(selfAssignQuestControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Mission ajoutée à vos quêtes.'
              : 'Impossible de prendre la mission : ${state.error}',
        ),
      ),
    );
  }
}

class _ChroniclesList extends StatelessWidget {
  const _ChroniclesList({required this.chronicles});

  final List<Chronicle> chronicles;

  @override
  Widget build(BuildContext context) {
    if (chronicles.isEmpty) {
      return const Column(
        children: [
          _ChronicleItem(
              emoji: '✨',
              title: 'Les Chroniques commencent',
              body: 'Les premiers événements apparaîtront ici.'),
          _ChronicleItem(
              emoji: '⚔️',
              title: 'Les premières quêtes arrivent bientôt',
              body: 'Le registre des missions est maintenant ouvert.'),
        ],
      );
    }

    return Column(
      children: chronicles
          .map((chronicle) => _ChronicleItem(
                emoji: _emojiForChronicleType(chronicle.type),
                title: chronicle.title,
                body: chronicle.body,
              ))
          .toList(),
    );
  }

  String _emojiForChronicleType(String type) {
    switch (type) {
      case 'kingdom_created':
        return '🏰';
      case 'domain_created':
        return '🏠';
      case 'quest_created':
        return '📜';
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
  const _ChronicleItem({required this.emoji, required this.title, this.body});

  final String emoji;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(body!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainsList extends StatelessWidget {
  const _DomainsList({required this.domains});

  final List<Domain> domains;

  @override
  Widget build(BuildContext context) {
    if (domains.isEmpty) return const Text('Aucun domaine pour le moment.');
    return Column(
        children:
            domains.map((domain) => _DomainTile(domain: domain)).toList());
  }
}

class _DomainTile extends StatelessWidget {
  const _DomainTile({required this.domain});

  final Domain domain;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(_emojiForDomain(domain.domainKind))),
      title: Text(domain.name),
      subtitle: Text(domain.isPrimary
          ? 'Domaine principal'
          : _labelForDomain(domain.domainKind)),
      trailing: domain.isPrimary
          ? const Icon(Icons.workspace_premium_outlined)
          : const Icon(Icons.chevron_right),
    );
  }

  String _emojiForDomain(String kind) {
    switch (kind) {
      case 'vacation':
        return '🏖';
      case 'grandparent':
        return '👵';
      case 'camp':
        return '🏕';
      case 'custom':
        return '✨';
      case 'home':
      default:
        return '🏠';
    }
  }

  String _labelForDomain(String kind) {
    switch (kind) {
      case 'vacation':
        return 'Maison de vacances';
      case 'grandparent':
        return 'Maison de grand-parent';
      case 'camp':
        return 'Camp ou lieu temporaire';
      case 'custom':
        return 'Domaine personnalisé';
      case 'home':
      default:
        return 'Maison';
    }
  }
}

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Le registre des quêtes est ouvert.'),
        SizedBox(height: 8),
        Text(
            'Prochain objectif : terminer une quête, gagner XP/or, puis alimenter les compétences.'),
      ],
    );
  }
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Ouverture du Livre des Chroniques...'),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Impossible d’ouvrir le Royaume',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Text('Erreur : $error');
  }
}

class _SoftErrorCard extends StatelessWidget {
  const _SoftErrorCard({required this.title, required this.error});

  final String title;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$title : $error'),
      ),
    );
  }
}
