import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/nature_animated_icon.dart';
import '../../boss/domain/boss.dart';
import '../../boss/providers/boss_provider.dart';
import '../../kingdom/domain/kingdom.dart';
import '../../kingdom/domain/kingdom_progress.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../../quests/domain/quest.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../quests/presentation/dialogs/quest_form_dialog.dart';
import '../../quests/presentation/dialogs/voluntary_quest_request_dialog.dart';
import '../../quests/providers/quests_provider.dart';
import '../../quests/providers/voluntary_quest_requests_provider.dart';
import '../../rewards/domain/reward_suggestion.dart';
import '../../rewards/providers/reward_suggestions_provider.dart';
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
    ref.watch(rewardSuggestionsRealtimeProvider);
    ref.watch(familyBossesRealtimeProvider);

    final familyAsync = ref.watch(currentFamilyProvider);
    final questsAsync = ref.watch(currentFamilyQuestsProvider);
    final wishesAsync = ref.watch(currentRewardSuggestionsProvider);
    final bossesAsync = ref.watch(currentFamilyBossesProvider);
    final currentMember = ref.watch(currentFamilyMemberProvider).asData?.value;
    final kingdoms =
        ref.watch(availableKingdomsProvider).valueOrNull ?? const <Kingdom>[];
    final currentKingdom = ref.watch(currentKingdomProvider).valueOrNull;
    final familyStats = ref.watch(currentFamilyStatsProvider).valueOrNull;
    final kingdomStage = familyStats == null
        ? KingdomStage.values.first
        : KingdomProgress.fromStats(familyStats).stage;
    final canManageQuests = currentKingdom?.membershipRole == 'guardian' &&
        currentMember?.isActive == true;
    final canProposeVoluntaryQuest =
        (currentKingdom?.membershipRole == 'adventurer' ||
                currentKingdom?.membershipRole == 'mercenary') &&
            currentMember?.isActive == true;
    final canSubmitVoluntaryQuest = ref.watch(canSubmitVoluntaryQuestProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    final pendingInitiatives =
        ref.watch(pendingVoluntaryQuestRequestCountProvider);

    Future<void> refreshAll() async {
      ref.invalidate(currentFamilyProvider);
      ref.invalidate(availableKingdomsProvider);
      ref.invalidate(currentFamilyQuestsProvider);
      ref.invalidate(currentFamilyBossesProvider);
      ref.invalidate(currentRewardSuggestionsProvider);
      ref.invalidate(guardianNotificationsProvider);
    }

    final navigationMenu = _HomeNavigationMenu(
      canManageQuests: canManageQuests,
      canSeeNotifications: currentMember?.isActive == true,
      canOpenInitiatives: canManageQuests || canSubmitVoluntaryQuest,
      unreadNotifications: unreadNotifications,
      pendingInitiatives: pendingInitiatives,
      onSignOut: () async {
        await Supabase.instance.client.auth.signOut();
        ref.invalidate(currentFamilyProvider);
      },
    );

    return Scaffold(
      drawer: navigationMenu,
      appBar: AppBar(
        title: const Text('HomeQuest'),
        actions: [
          if (currentMember?.isActive == true)
            IconButton(
              tooltip: 'Notifications du royaume',
              onPressed: () => context.go('/notifications'),
              icon: Badge(
                isLabelVisible: unreadNotifications > 0,
                label: Text('$unreadNotifications'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          PopupMenuButton<_AccountAction>(
            tooltip: 'Compte et réglages',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (action) async {
              switch (action) {
                case _AccountAction.profile:
                  context.go('/profile');
                case _AccountAction.appearance:
                  context.go('/appearance');
                case _AccountAction.devtools:
                  context.go('/devtools');
                case _AccountAction.signOut:
                  await Supabase.instance.client.auth.signOut();
                  ref.invalidate(currentFamilyProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _AccountAction.profile,
                child: Text('Mon profil'),
              ),
              const PopupMenuItem(
                value: _AccountAction.appearance,
                child: Text('Apparence'),
              ),
              if (kDebugMode)
                const PopupMenuItem(
                  value: _AccountAction.devtools,
                  child: Text('Outils de développement'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _AccountAction.signOut,
                child: Text('Déconnexion'),
              ),
            ],
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
                _HeroHeader(
                  family: family,
                  kingdom: currentKingdom,
                  stage: kingdomStage,
                  availableKingdoms: kingdoms,
                  onSelectKingdom: (kingdomId) {
                    ref.read(selectedKingdomIdProvider.notifier).state =
                        kingdomId;
                  },
                  onOpenKingdom: () => context.go('/kingdom-progress'),
                  onOpenLegend: () => context.go('/kingdom-legend'),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '📜 Quêtes en cours',
                  subtitle: 'Les missions prioritaires de votre guilde.',
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
                      : canProposeVoluntaryQuest
                          ? FilledButton.tonalIcon(
                              onPressed: canSubmitVoluntaryQuest
                                  ? () => showDialog<void>(
                                        context: context,
                                        builder: (_) =>
                                            const VoluntaryQuestRequestDialog(),
                                      )
                                  : null,
                              icon: Icon(
                                canSubmitVoluntaryQuest
                                    ? Icons.volunteer_activism
                                    : Icons.lock_outline,
                              ),
                              label: Text(
                                canSubmitVoluntaryQuest
                                    ? 'Je voudrais accomplir une quête'
                                    : 'Aventurier niveau 10 requis',
                              ),
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
                _KingdomChallenges(
                  wishesAsync: wishesAsync,
                  bossesAsync: bossesAsync,
                  onOpenWishes: () => context.go('/reward-suggestions'),
                  onOpenBosses: () => context.go('/bosses'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _AccountAction { profile, appearance, devtools, signOut }

class _HomeNavigationMenu extends StatelessWidget {
  const _HomeNavigationMenu({
    required this.canManageQuests,
    required this.canSeeNotifications,
    required this.canOpenInitiatives,
    required this.unreadNotifications,
    required this.pendingInitiatives,
    required this.onSignOut,
  });

  final bool canManageQuests;
  final bool canSeeNotifications;
  final bool canOpenInitiatives;
  final int unreadNotifications;
  final int pendingInitiatives;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    void open(String location) => context.go(location);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.castle_outlined)),
              title: Text('HomeQuest'),
              subtitle: Text('Navigation du Royaume'),
            ),
            const Divider(),
            const _MenuSectionTitle('Royaume'),
            _MenuItem(
              icon: Icons.home_outlined,
              label: 'Accueil',
              onTap: () => open('/dashboard'),
            ),
            _MenuItem(
              icon: Icons.castle_outlined,
              label: 'Évolution du Royaume',
              onTap: () => open('/kingdom-progress'),
            ),
            _MenuItem(
              icon: Icons.groups_outlined,
              label: 'Membres du royaume',
              onTap: () => open('/members'),
            ),
            _MenuItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Hall des Héros',
              onTap: () => open('/heroes'),
            ),
            _MenuItem(
              icon: Icons.auto_stories_outlined,
              label: 'Légende du Royaume',
              onTap: () => open('/kingdom-legend'),
            ),
            const _MenuSectionTitle('Aventure'),
            _MenuItem(
              icon: Icons.task_alt_outlined,
              label: 'Quêtes',
              onTap: () => open('/quests'),
            ),
            _MenuItem(
              icon: Icons.assignment_turned_in_outlined,
              label: 'Mes missions',
              onTap: () => open('/missions'),
            ),
            _MenuItem(
              icon: Icons.local_fire_department_outlined,
              label: 'Antre des Boss',
              onTap: () => open('/bosses'),
            ),
            if (canOpenInitiatives)
              _MenuItem(
                icon: Icons.volunteer_activism_outlined,
                label: canManageQuests
                    ? 'Initiatives à examiner'
                    : 'Mes initiatives',
                badgeCount: pendingInitiatives,
                onTap: () => open('/quest-requests'),
              ),
            _MenuItem(
              icon: Icons.card_giftcard_outlined,
              label: 'Souhaits et récompenses',
              onTap: () => open('/reward-suggestions'),
            ),
            const _MenuSectionTitle('Foyer'),
            _MenuItem(
              icon: Icons.shopping_basket_outlined,
              label: 'Liste de ravitaillement',
              onTap: () => open('/shopping'),
            ),
            if (canSeeNotifications) ...[
              if (canManageQuests) const _MenuSectionTitle('Gestion du gardien'),
              if (canManageQuests)
                _MenuItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Validations en attente',
                  onTap: () => open('/validations'),
                ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                badgeCount: unreadNotifications,
                onTap: () => open('/notifications'),
              ),
            ],
            const Divider(),
            _MenuItem(
              icon: Icons.person_outline,
              label: 'Mon profil',
              onTap: () => open('/profile'),
            ),
            _MenuItem(
              icon: Icons.palette_outlined,
              label: 'Apparence',
              onTap: () => open('/appearance'),
            ),
            _MenuItem(
              icon: Icons.notifications_active_outlined,
              label: 'Préférences des notifications',
              onTap: () => open('/notification-preferences'),
            ),
            _MenuItem(
              icon: Icons.logout,
              label: 'Déconnexion',
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 16, 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Badge(
          isLabelVisible: badgeCount > 0,
          label: Text('$badgeCount'),
          child: Icon(icon),
        ),
        title: Text(label),
        onTap: onTap,
      );
}

class _KingdomChallenges extends StatelessWidget {
  const _KingdomChallenges({
    required this.wishesAsync,
    required this.bossesAsync,
    required this.onOpenWishes,
    required this.onOpenBosses,
  });

  final AsyncValue<List<RewardSuggestion>> wishesAsync;
  final AsyncValue<List<Boss>> bossesAsync;
  final VoidCallback onOpenWishes;
  final VoidCallback onOpenBosses;

  @override
  Widget build(BuildContext context) {
    final rewards = _SectionCard(
      title: '🎁 Récompenses du Royaume',
      subtitle: 'Les objectifs collectifs approuvés par les Gardiens.',
      action: TextButton.icon(
        onPressed: onOpenWishes,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Voir les souhaits'),
      ),
      child: wishesAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => _InlineError(error: error),
        data: (suggestions) => _CollectiveWishesPanel(
          suggestions: suggestions,
        ),
      ),
    );

    final fights = _SectionCard(
      title: '🐉 Affrontements en cours',
      subtitle: 'Chaque quête accomplie rapproche la guilde de la victoire.',
      action: TextButton.icon(
        onPressed: onOpenBosses,
        icon: const Icon(Icons.local_fire_department_outlined),
        label: const Text('Ouvrir l’antre'),
      ),
      child: bossesAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => _InlineError(error: error),
        data: (bosses) => _ActiveBossPanel(bosses: bosses),
      ),
    );

    return Column(
      children: [
        fights,
        const SizedBox(height: 16),
        rewards,
      ],
    );
  }
}

class _CollectiveWishesPanel extends StatelessWidget {
  const _CollectiveWishesPanel({required this.suggestions});

  final List<RewardSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final accepted =
        suggestions.where((suggestion) => suggestion.isCollective).toList()
          ..sort((left, right) {
            if (left.isFulfilled == right.isFulfilled) {
              return right.createdAt.compareTo(left.createdAt);
            }
            return left.isFulfilled ? 1 : -1;
          });

    if (accepted.isEmpty) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.auto_awesome_outlined),
        title: Text('Aucun souhait collectif actif.'),
        subtitle: Text(
          'Les souhaits acceptés par un Gardien apparaîtront ici.',
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < accepted.length; index++) ...[
          _CollectiveWishTile(suggestion: accepted[index]),
          if (index < accepted.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }
}

class _CollectiveWishTile extends StatelessWidget {
  const _CollectiveWishTile({required this.suggestion});

  final RewardSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questGoal = suggestion.guardianQuestCount ?? 0;
    final questProgress = questGoal <= 0
        ? null
        : (suggestion.completedQuestCount / questGoal).clamp(0.0, 1.0);
    final title = suggestion.guardianTitle?.trim().isNotEmpty == true
        ? suggestion.guardianTitle!
        : suggestion.title;
    final description =
        suggestion.guardianDescription?.trim().isNotEmpty == true
            ? suggestion.guardianDescription!
            : suggestion.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              suggestion.isDelivered
                  ? Icons.redeem
                  : suggestion.isFulfilled
                      ? Icons.check_circle
                      : Icons.card_giftcard,
              color: suggestion.isFulfilled
                  ? Colors.green
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    suggestion.isDelivered
                        ? 'Récompense remise au Royaume'
                        : suggestion.isFulfilled
                            ? 'Récompense débloquée — remise en attente'
                            : suggestion.createdByGuardian
                                ? 'Objectif officiel fixé par les Gardiens'
                                : 'Souhait proposé par ${suggestion.proposerName}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description),
        ],
        if (questProgress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: questProgress.toDouble()),
          const SizedBox(height: 5),
          Text(
            '${suggestion.completedQuestCount.clamp(0, questGoal)} / '
            '$questGoal quêtes accomplies',
            style: theme.textTheme.labelMedium,
          ),
        ],
        if (suggestion.guardianBossTheme?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Chip(
            avatar: const Icon(Icons.local_fire_department, size: 18),
            label: Text('Boss : ${suggestion.guardianBossTheme}'),
          ),
        ],
      ],
    );
  }
}

class _ActiveBossPanel extends StatelessWidget {
  const _ActiveBossPanel({required this.bosses});

  final List<Boss> bosses;

  @override
  Widget build(BuildContext context) {
    Boss? activeBoss;
    for (final boss in bosses) {
      if (boss.isActive) {
        activeBoss = boss;
        break;
      }
    }

    if (activeBoss == null) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.shield_outlined),
        title: Text('Le Royaume est en paix.'),
        subtitle: Text('Aucun boss n’est invoqué pour le moment.'),
      );
    }

    final boss = activeBoss;
    final theme = Theme.of(context);
    final health = boss.healthProgress.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(boss.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    boss.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('${boss.element} • ${boss.domainLabel}'),
                ],
              ),
            ),
          ],
        ),
        if (boss.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(boss.description),
        ],
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: health,
          minHeight: 12,
          borderRadius: BorderRadius.circular(999),
          color: health < 0.3 ? Colors.green : theme.colorScheme.error,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${boss.currentHp} / ${boss.maxHp} PV',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text('Difficulté ${boss.difficulty}/5'),
          ],
        ),
        if (boss.specialItem.isNotEmpty) ...[
          const SizedBox(height: 10),
          Chip(
            avatar: const Icon(Icons.inventory_2_outlined, size: 18),
            label: Text('Butin : ${boss.specialItem}'),
          ),
        ],
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.family,
    required this.kingdom,
    required this.stage,
    required this.availableKingdoms,
    required this.onSelectKingdom,
    required this.onOpenKingdom,
    required this.onOpenLegend,
  });

  final domain.Family family;
  final Kingdom? kingdom;
  final KingdomStage stage;
  final List<Kingdom> availableKingdoms;
  final ValueChanged<String> onSelectKingdom;
  final VoidCallback onOpenKingdom;
  final VoidCallback onOpenLegend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Ink(
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
        child: InkWell(
          onTap: onOpenKingdom,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(
              children: [
                Semantics(
                  label: 'Étape actuelle du Royaume : ${stage.name}',
                  child: NatureAnimatedIcon(
                    motion: kingdomNatureMotion(stage.emoji),
                    child: Text(
                      stage.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kingdom?.name ?? family.kingdomName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Étape actuelle : ${stage.name}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Guilde familiale : ${family.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (availableKingdoms.length > 1)
                  PopupMenuButton<String>(
                    tooltip: 'Changer de Royaume',
                    initialValue: kingdom?.id,
                    onSelected: onSelectKingdom,
                    icon: Icon(
                      Icons.swap_horiz,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    itemBuilder: (context) => [
                      for (final option in availableKingdoms)
                        PopupMenuItem<String>(
                          value: option.id,
                          child: Row(
                            children: [
                              Text(
                                option.icon,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(option.name)),
                              if (option.id == kingdom?.id)
                                const Icon(Icons.check, size: 18),
                            ],
                          ),
                        ),
                    ],
                  ),
                IconButton.filledTonal(
                  tooltip: 'Ouvrir le Carnet des légendes',
                  onPressed: onOpenLegend,
                  icon: Icon(
                    Icons.menu_book_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
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
                key: ValueKey(quest.id),
                quest: quest,
                compactOnMobile: true,
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
