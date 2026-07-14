import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/rpg_profile_repository_impl.dart';
import '../domain/rpg_profile.dart';
import '../providers/rpg_profile_provider.dart';

class RpgProfilePage extends ConsumerWidget {
  const RpgProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentRpgProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour au royaume',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Profil d’aventurier'),
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
              _ProgressCard(profile: value),
              const SizedBox(height: 16),
              _HarmonyCard(profile: value),
              const SizedBox(height: 16),
              _SkillsSection(skills: value.skills),
              const SizedBox(height: 16),
              _AdventuresSection(adventures: value.recentAdventures),
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
      builder: (_) => _EditProfileDialog(profile: profile),
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
              child: Text(
                avatarEmoji(profile.avatarKey),
                style: const TextStyle(fontSize: 48),
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

class _AdventuresSection extends StatelessWidget {
  const _AdventuresSection({required this.adventures});

  final List<RpgAdventure> adventures;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dernières aventures',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (adventures.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.auto_stories_outlined),
              title: Text('Votre chronique personnelle commence ici.'),
              subtitle: Text(
                'Les missions validées apparaîtront dans cette section.',
              ),
            ),
          )
        else
          for (final adventure in adventures)
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

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile});

  final RpgProfile profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late String _avatarKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _avatarKey = rpgAvatarKeys.contains(widget.profile.avatarKey)
        ? widget.profile.avatarKey!
        : 'explorer';
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
              Text('Avatar', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in rpgAvatars.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _avatarKey = entry.key),
                      child: Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: _avatarKey == entry.key
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          border: Border.all(
                            color: _avatarKey == entry.key
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
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
