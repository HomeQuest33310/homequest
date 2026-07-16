import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/dashboard_home_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/profile_avatar.dart';
import '../domain/rpg_profile.dart';
import '../providers/rpg_profile_provider.dart';
import 'widgets/profile_avatar_view.dart';

class RpgProfilePage extends ConsumerWidget {
  const RpgProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentRpgProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Profil d’aventurier'),
        actions: [
          IconButton(
            tooltip: 'Souhaits de récompenses',
            onPressed: () => context.go('/reward-suggestions'),
            icon: const Icon(Icons.card_giftcard),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ProfileError(
          error: error,
          onRetry: () => ref.invalidate(currentRpgProfileProvider),
        ),
        data: (value) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentRpgProfileProvider);
            await ref.read(currentRpgProfileProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HeroCard(
                profile: value,
                onEdit: () => _showEditProfileDialog(context, ref, value),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.card_giftcard),
                  ),
                  title: const Text('Souhaits de récompenses'),
                  subtitle: Text(
                    value.role == 'guardian'
                        ? 'Examiner les propositions des aventuriers.'
                        : 'Proposer une récompense aux Gardiens.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/reward-suggestions'),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.key_outlined)),
                  title: const Text('Sécurité du compte'),
                  subtitle: const Text(
                    'Recevoir un lien pour choisir un nouveau mot de passe.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _requestOwnPasswordReset(context, ref),
                ),
              ),
              const SizedBox(height: 16),
              _ProgressCard(profile: value),
              const SizedBox(height: 16),
              _HarmonyCard(profile: value),
              const SizedBox(height: 16),
              _AchievementsSection(achievements: value.achievements),
              const SizedBox(height: 16),
              _SkillsSection(skills: value.skills),
              const SizedBox(height: 16),
              _ElementalAspectsSection(aspects: value.elementalAspects),
              const SizedBox(height: 16),
              _BossTrophiesSection(trophies: value.bossTrophies),
              const SizedBox(height: 16),
              _JournalSection(
                adventures: value.recentAdventures,
                bossVictories: value.bossVictories,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    RpgProfile profile,
  ) async {
    final result = await showDialog<_ProfileEdition>(
      context: context,
      builder: (_) => _EditProfileDialog(
        profile: profile,
        onPurchase: (avatarKey) => ref
            .read(rpgProfileControllerProvider.notifier)
            .purchaseAvatar(avatarKey),
      ),
    );
    if (result == null || !context.mounted) return;

    final success =
        await ref.read(rpgProfileControllerProvider.notifier).updateProfile(
              displayName: result.displayName,
              avatarKey: result.avatarKey,
            );
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil d’aventurier mis à jour.')),
      );
      return;
    }

    final error = ref.read(rpgProfileControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossible de modifier le profil : $error')),
    );
  }

  Future<void> _requestOwnPasswordReset(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final email = ref.read(currentUserProvider)?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucune adresse e-mail n’est associée à ce compte.')),
      );
      return;
    }

    try {
      await ref.read(passwordResetServiceProvider).requestForEmail(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le lien de réinitialisation a été envoyé par e-mail.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoi impossible : $error')),
      );
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile, required this.onEdit});

  final RpgProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = _harmonyColors(profile.harmonyRank);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9),
                border: Border.all(color: Colors.white, width: 4),
              ),
              alignment: Alignment.center,
              child: ProfileAvatarView(
                avatarKey: profile.avatarKey,
                size: 84,
                semanticLabel: 'Avatar de ${profile.displayName}',
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.rpgTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LightBadge(label: profile.roleLabel),
                      _LightBadge(label: profile.kingdomName),
                    ],
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Modifier mon profil',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightBadge extends StatelessWidget {
  const _LightBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.profile});

  final RpgProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatTile(
                  icon: Icons.military_tech,
                  label: 'Niveau',
                  value: '${profile.level}',
                ),
                _StatTile(
                  icon: Icons.auto_awesome,
                  label: 'Expérience',
                  value: '${profile.xp} XP',
                ),
                _StatTile(
                  icon: Icons.monetization_on,
                  label: 'Trésor',
                  value: '${profile.gold} or',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Progression vers le niveau ${profile.level + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${profile.xpInCurrentLevel}/${profile.xpNeededForLevel} XP',
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: profile.levelProgress,
                minHeight: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HarmonyCard extends StatelessWidget {
  const _HarmonyCard({required this.profile});

  final RpgProfile profile;

  @override
  Widget build(BuildContext context) {
    final rank = profile.harmonyRank;
    const ranks = HarmonyRank.values;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.diversity_3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Harmonie ${rank.label}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('${profile.developedSkills} talents développés'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Varier les types de missions fait grandir votre Harmonie et '
              'débloque des ornements pour votre profil.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final candidate in ranks)
                  Chip(
                    avatar: Icon(
                      candidate.index <= rank.index
                          ? Icons.check_circle
                          : Icons.lock_outline,
                      size: 18,
                    ),
                    label: Text(
                      '${candidate.label} · ${_harmonyReward(candidate)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({required this.achievements});

  final List<RpgAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((item) => item.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Succès et titres',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Chip(
              avatar: const Icon(Icons.emoji_events, size: 18),
              label: Text('$unlocked/${achievements.length} débloqués'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Les aventures, les talents et les victoires contre les boss '
          'débloqueront de nouveaux titres héroïques.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 760
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final achievement in achievements)
                  SizedBox(
                    width: cardWidth,
                    child: _AchievementCard(achievement: achievement),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final RpgAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlocked = achievement.isUnlocked;
    final current = achievement.current.clamp(0, achievement.target);

    return Card(
      color: unlocked ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: unlocked
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                achievement.emoji,
                style: TextStyle(
                  fontSize: 28,
                  color: unlocked ? null : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        unlocked ? Icons.verified : Icons.lock_outline,
                        color:
                            unlocked ? scheme.primary : scheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unlocked
                        ? 'Titre débloqué'
                        : '$current/${achievement.target}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          unlocked ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.skills});

  final List<RpgSkill> skills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compétences', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Chaque mission validée développe les talents associés.'),
        const SizedBox(height: 12),
        for (final skill in skills)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(skill.icon, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                skill.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              skill.xp == 0
                                  ? 'À découvrir'
                                  : 'Niv. ${skill.level}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          skill.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: skill.progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 4),
                        Text('${skill.xp} XP de compétence'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ElementalAspectsSection extends StatelessWidget {
  const _ElementalAspectsSection({required this.aspects});

  final List<ElementalAspect> aspects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aspects élémentaires',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text('Chaque boss vaincu renforce son aspect sur votre profil.'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: aspects.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.blur_on_outlined),
                    title: Text('Aucun aspect éveillé pour le moment.'),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final aspect in aspects)
                        Chip(
                          avatar: Text(aspect.emoji),
                          label: Text('${aspect.element} ×${aspect.count}'),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _BossTrophiesSection extends StatelessWidget {
  const _BossTrophiesSection({required this.trophies});

  final List<BossTrophy> trophies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Objets remportés',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (trophies.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('Votre collection de trophées est encore vide.'),
              subtitle: Text('Les objets des boss vaincus apparaîtront ici.'),
            ),
          )
        else
          for (final trophy in trophies)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(trophy.bossEmoji)),
                title: Text(trophy.name),
                subtitle: Text(
                  'Remporté contre ${trophy.bossName} · '
                  '${DateFormat('dd/MM/yyyy').format(trophy.wonAt.toLocal())}',
                ),
              ),
            ),
      ],
    );
  }
}

class _JournalSection extends StatelessWidget {
  const _JournalSection({
    required this.adventures,
    required this.bossVictories,
  });

  final List<RpgAdventure> adventures;
  final List<RpgBossVictory> bossVictories;

  @override
  Widget build(BuildContext context) {
    final entries = <_JournalEntry>[
      for (final adventure in adventures) _JournalEntry.quest(adventure),
      for (final victory in bossVictories) _JournalEntry.boss(victory),
    ]..sort((left, right) => right.date.compareTo(left.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Journal de l’aventurier',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.auto_stories_outlined),
              title: Text('Votre chronique personnelle commence ici.'),
              subtitle: Text(
                'Les quêtes accomplies et les boss vaincus apparaîtront ici.',
              ),
            ),
          )
        else
          for (final entry in entries)
            if (entry.bossVictory case final victory?)
              _BossJournalCard(victory: victory)
            else if (entry.adventure case final adventure?)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.emoji_events)),
                  title: Text(adventure.title),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy')
                        .format(adventure.completedAt.toLocal()),
                  ),
                  trailing: Text(
                    '+${adventure.xpReward} XP\n+${adventure.goldReward} or',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
      ],
    );
  }
}

class _BossJournalCard extends StatelessWidget {
  const _BossJournalCard({required this.victory});

  final RpgBossVictory victory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 26,
                child:
                    Text(victory.emoji, style: const TextStyle(fontSize: 26)),
              ),
              title: Text(
                '${victory.name} vaincu !',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(
                '${victory.element} · '
                '${DateFormat('dd/MM/yyyy').format(victory.defeatedAt.toLocal())}',
              ),
              trailing: Text('+${victory.xpReward} XP'),
            ),
            const SizedBox(height: 8),
            Text(
              'Guilde victorieuse',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final participant in victory.participants)
                  Chip(
                    avatar: const Icon(Icons.person, size: 18),
                    label: Text(participant.displayName),
                  ),
              ],
            ),
            if (victory.specialItem.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Objet : ${victory.specialItem}')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JournalEntry {
  const _JournalEntry._({
    required this.date,
    this.adventure,
    this.bossVictory,
  });

  factory _JournalEntry.quest(RpgAdventure adventure) => _JournalEntry._(
        date: adventure.completedAt,
        adventure: adventure,
      );

  factory _JournalEntry.boss(RpgBossVictory victory) => _JournalEntry._(
        date: victory.defeatedAt,
        bossVictory: victory,
      );

  final DateTime date;
  final RpgAdventure? adventure;
  final RpgBossVictory? bossVictory;
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.profile,
    required this.onPurchase,
  });

  final RpgProfile profile;
  final Future<int> Function(String avatarKey) onPurchase;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late String _avatarKey;
  late Set<String> _unlockedAvatarKeys;
  late int _gold;
  String? _purchasingAvatarKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _avatarKey = profileAvatarKeys.contains(widget.profile.avatarKey)
        ? widget.profile.avatarKey!
        : 'explorer';
    _unlockedAvatarKeys = {...widget.profile.unlockedAvatarKeys};
    _gold = widget.profile.gold;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Personnaliser mon aventurier'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                maxLength: 32,
                decoration: const InputDecoration(
                  labelText: 'Nom d’aventurier',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Avatars gratuits',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final avatar
                      in profileAvatarCatalog.where((item) => !item.isPremium))
                    _AvatarChoice(
                      avatar: avatar,
                      isSelected: _avatarKey == avatar.key,
                      isUnlocked: true,
                      isPurchasing: false,
                      onTap: () => setState(() => _avatarKey = avatar.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Avatars à débloquer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.monetization_on, size: 18),
                    label: Text('$_gold or'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Chaque avatar coûte 100 pièces d’or et reste ensuite débloqué.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final avatar
                      in profileAvatarCatalog.where((item) => item.isPremium))
                    _AvatarChoice(
                      avatar: avatar,
                      isSelected: _avatarKey == avatar.key,
                      isUnlocked: _unlockedAvatarKeys.contains(avatar.key),
                      isPurchasing: _purchasingAvatarKey == avatar.key,
                      onTap: () => _selectAvatar(avatar),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Le nom doit contenir au moins 2 caractères.'),
                ),
              );
              return;
            }
            Navigator.of(context).pop(
              _ProfileEdition(displayName: name, avatarKey: _avatarKey),
            );
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _selectAvatar(ProfileAvatarOption avatar) async {
    if (!avatar.isPremium || _unlockedAvatarKeys.contains(avatar.key)) {
      setState(() => _avatarKey = avatar.key);
      return;
    }
    if (_purchasingAvatarKey != null) return;

    if (_gold < avatar.goldPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Il faut ${avatar.goldPrice} pièces d’or pour débloquer '
            '${avatar.label}.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Débloquer ${avatar.label} ?'),
        content: Text(
          '${avatar.goldPrice} pièces d’or seront retirées de votre solde. '
          'Cet avatar restera disponible définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.monetization_on),
            label: Text('Acheter ${avatar.goldPrice} or'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _purchasingAvatarKey = avatar.key);
    try {
      final remainingGold = await widget.onPurchase(avatar.key);
      if (!mounted) return;
      setState(() {
        _gold = remainingGold;
        _unlockedAvatarKeys.add(avatar.key);
        _avatarKey = avatar.key;
        _purchasingAvatarKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${avatar.label} est maintenant débloqué.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _purchasingAvatarKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Achat impossible : $error')),
      );
    }
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.avatar,
    required this.isSelected,
    required this.isUnlocked,
    required this.isPurchasing,
    required this.onTap,
  });

  final ProfileAvatarOption avatar;
  final bool isSelected;
  final bool isUnlocked;
  final bool isPurchasing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: avatar.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: avatar.isPremium ? 92 : 62,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            border: Border.all(
              color: isSelected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ProfileAvatarView(
                    avatarKey: avatar.key,
                    size: avatar.isPremium ? 80 : 50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  if (avatar.isPremium)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: scheme.surface.withValues(alpha: 0.9),
                        child: isPurchasing
                            ? const SizedBox.square(
                                dimension: 13,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                isUnlocked ? Icons.check : Icons.lock,
                                size: 14,
                                color: isUnlocked
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                      ),
                    ),
                ],
              ),
              if (avatar.isPremium) ...[
                const SizedBox(height: 4),
                Text(
                  isUnlocked ? 'Débloqué' : '${avatar.goldPrice} or',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isUnlocked ? scheme.primary : null,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEdition {
  const _ProfileEdition({required this.displayName, required this.avatarKey});

  final String displayName;
  final String avatarKey;
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text('Impossible de charger le profil : $error'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

List<Color> _harmonyColors(HarmonyRank rank) {
  switch (rank) {
    case HarmonyRank.awakening:
      return const [Color(0xFF475569), Color(0xFF6366F1)];
    case HarmonyRank.bronze:
      return const [Color(0xFF92400E), Color(0xFFD97706)];
    case HarmonyRank.silver:
      return const [Color(0xFF64748B), Color(0xFF94A3B8)];
    case HarmonyRank.gold:
      return const [Color(0xFFB45309), Color(0xFFF59E0B)];
    case HarmonyRank.platinum:
      return const [Color(0xFF0F766E), Color(0xFF2DD4BF)];
    case HarmonyRank.rainbow:
      return const [Color(0xFF7C3AED), Color(0xFFEC4899)];
  }
}

String _harmonyReward(HarmonyRank rank) {
  switch (rank) {
    case HarmonyRank.awakening:
      return 'Emblème d’explorateur';
    case HarmonyRank.bronze:
      return 'Cadre bronze';
    case HarmonyRank.silver:
      return 'Bannière argentée';
    case HarmonyRank.gold:
      return 'Aura dorée';
    case HarmonyRank.platinum:
      return 'Halo de platine';
    case HarmonyRank.rainbow:
      return 'Emblème légendaire';
  }
}
