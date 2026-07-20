import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/dashboard_home_button.dart';
import '../../../core/theme/app_appearance.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/appearance_provider.dart';
import '../../family/providers/family_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
    final kingdoms =
        ref.watch(availableKingdomsProvider).valueOrNull ?? const [];
    final canCreateKingdom = kingdoms.any(
      (available) =>
          available.membershipRole == 'guardian' ||
          available.membershipRole == 'adventurer',
    );
    final leaveState = ref.watch(leaveKingdomControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Apparence du Royaume'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choisis ton ambiance',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Le moteur de thèmes pourra accueillir de nouveaux univers sans modifier les écrans.',
          ),
          const SizedBox(height: 18),
          _AccountKingdomActions(
            kingdomName: kingdom?.name,
            canCreateKingdom: canCreateKingdom,
            isLeaving: leaveState.isLoading,
            onCreateKingdom: () => _confirmCreateKingdom(context),
            onLeaveKingdom: kingdom == null
                ? null
                : () => _confirmLeaveKingdom(context, ref, kingdom.id),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 560
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final style in HomeQuestThemeStyle.values)
                    SizedBox(
                      width: width,
                      child: _ThemeChoiceCard(
                        style: style,
                        selected: appearance.style == style,
                        onSelected: () => controller.selectStyle(style),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Vision Reptilienne',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('${(appearance.reptilianLevel * 100).round()} %'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ajuste la distinction des couleurs et le contraste selon ta vision. Chaque thème garde son propre réglage.',
                  ),
                  Slider(
                    value: appearance.reptilianLevel,
                    divisions: 10,
                    label: '${(appearance.reptilianLevel * 100).round()} %',
                    onChanged: controller.setReptilianLevel,
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ambiance originale'),
                      Text('Contraste maximal'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _LivePreview(),
        ],
      ),
    );
  }

  Future<void> _confirmCreateKingdom(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Créer un nouveau Royaume ?'),
        content: const Text(
          'Attention : créer un Royaume signifie également devoir gérer les quêtes, les membres et les responsabilités qui lui sont liés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.push('/create-family');
    }
  }

  Future<void> _confirmLeaveKingdom(
    BuildContext context,
    WidgetRef ref,
    String kingdomId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter le Royaume ?'),
        content: const Text(
          'Attention : vous êtes sur le point de quitter le Royaume. Vous ne pourrez pas récupérer vos bonus ni vos gains liés à ce Royaume.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitter le Royaume'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(leaveKingdomControllerProvider.notifier)
        .leaveKingdom(kingdomId);
    if (!context.mounted) return;

    final state = ref.read(leaveKingdomControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de quitter le Royaume : ${state.error}'),
        ),
      );
      return;
    }
    context.go('/');
  }
}

class _AccountKingdomActions extends StatelessWidget {
  const _AccountKingdomActions({
    required this.kingdomName,
    required this.canCreateKingdom,
    required this.isLeaving,
    required this.onCreateKingdom,
    required this.onLeaveKingdom,
  });

  final String? kingdomName;
  final bool canCreateKingdom;
  final bool isLeaving;
  final VoidCallback onCreateKingdom;
  final VoidCallback? onLeaveKingdom;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestion du compte',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(kingdomName == null
                ? 'Actions liées à votre aventure.'
                : 'Royaume actif : $kingdomName'),
            const SizedBox(height: 16),
            if (canCreateKingdom)
              FilledButton.tonalIcon(
                onPressed: onCreateKingdom,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Créer un nouveau Royaume'),
              ),
            if (canCreateKingdom) const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isLeaving ? null : onLeaveKingdom,
              icon: isLeaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.exit_to_app_outlined),
              label: const Text('Quitter le Royaume'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    required this.style,
    required this.selected,
    required this.onSelected,
  });

  final HomeQuestThemeStyle style;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.build(
      AppAppearance(style: style),
    ).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: selected ? 3 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary, width: 3),
                ),
                alignment: Alignment.center,
                child: Icon(style.icon, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(style.description),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aperçu en direct',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(value: 0.68),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('⚔️ Quête active')),
                Chip(label: Text('⭐ 120 XP')),
                Chip(label: Text('🎁 Récompense')),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Bouton du Royaume'),
            ),
          ],
        ),
      ),
    );
  }
}
