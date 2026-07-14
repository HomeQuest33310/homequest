import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/rpg_profile_repository_impl.dart';
import '../domain/rpg_profile.dart';
import '../providers/rpg_profile_provider.dart';

class HeroesHallPage extends ConsumerWidget {
  const HeroesHallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(familyRpgProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour au Royaume',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Hall des Héros'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(familyRpgProfilesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HallError(
          error: error,
          onRetry: () => ref.invalidate(familyRpgProfilesProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(familyRpgProfilesProvider);
            await ref.read(familyRpgProfilesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HallHeader(profiles: items),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Le Hall attend ses premiers héros.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth >= 600
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final profile in items)
                          SizedBox(
                            width: width,
                            child: _HeroHallCard(profile: profile),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HallHeader extends StatelessWidget {
  const _HallHeader({required this.profiles});

  final List<RpgProfile> profiles;

  @override
  Widget build(BuildContext context) {
    final guardians = profiles.where((item) => item.role == 'guardian').length;
    final mercenaries =
        profiles.where((item) => item.role == 'mercenary').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏰', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Les héros du Royaume',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Text(
                        'Chaque talent compte. Le Hall célèbre les parcours '
                        'sans classer les membres de la guilde.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.groups, size: 18),
                  label: Text('${profiles.length} héros actifs'),
                ),
                Chip(
                  avatar: const Icon(Icons.shield, size: 18),
                  label: Text('$guardians Gardiens'),
                ),
                if (mercenaries > 0)
                  Chip(
                    avatar: const Icon(Icons.explore, size: 18),
                    label: Text('$mercenaries Mercenaires'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHallCard extends StatelessWidget {
  const _HeroHallCard({required this.profile});

  final RpgProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked =
        profile.achievements.where((achievement) => achievement.isUnlocked);
    final topSkills = profile.skills.where((skill) => skill.xp > 0).take(3);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showHeroDetails(context, profile),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      avatarEmoji(profile.avatarKey),
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(profile.rpgTitle),
                        const SizedBox(height: 6),
                        _RoleBadge(profile: profile),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Metric(
                      icon: Icons.military_tech, text: 'Niv. ${profile.level}'),
                  _Metric(icon: Icons.star, text: '${profile.xp} XP'),
                  _Metric(
                    icon: Icons.emoji_events,
                    text: '${unlocked.length} succès',
                  ),
                  if (profile.bossVictories.isNotEmpty)
                    _Metric(
                      icon: Icons.local_fire_department,
                      text: '${profile.bossVictories.length} boss',
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Talents remarquables', style: theme.textTheme.labelLarge),
              const SizedBox(height: 7),
              if (topSkills.isEmpty)
                Text(
                  'Une première quête révélera ses talents.',
                  style: theme.textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in topSkills)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Text(skill.icon),
                        label: Text('${skill.name} · Niv. ${skill.level}'),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showHeroDetails(context, profile),
                  icon: const Icon(Icons.auto_stories),
                  label: const Text('Voir ses titres'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.profile});

  final RpgProfile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          profile.roleLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 17),
      label: Text(text),
    );
  }
}

void _showHeroDetails(BuildContext context, RpgProfile profile) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            '${avatarEmoji(profile.avatarKey)} ${profile.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(profile.rpgTitle),
          const SizedBox(height: 18),
          for (final achievement in profile.achievements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(achievement.emoji)),
              title: Text(achievement.title),
              subtitle: Text(achievement.description),
              trailing: Icon(
                achievement.isUnlocked ? Icons.verified : Icons.lock_outline,
              ),
            ),
        ],
      ),
    ),
  );
}

class _HallError extends StatelessWidget {
  const _HallError({required this.error, required this.onRetry});

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
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              'Impossible d’ouvrir le Hall des Héros : $error',
              textAlign: TextAlign.center,
            ),
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
