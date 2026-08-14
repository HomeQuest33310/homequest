import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/dashboard_home_button.dart';
import '../../../family/providers/family_members_provider.dart';
import '../../../kingdom/providers/kingdom_provider.dart';
import '../../providers/quests_provider.dart';
import '../../providers/voluntary_quest_requests_provider.dart';
import '../../domain/quest.dart';
import '../dialogs/assign_quest_dialog.dart';
import '../dialogs/quest_form_dialog.dart';
import '../dialogs/voluntary_quest_request_dialog.dart';
import '../widgets/quest_card.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(currentFamilyQuestsProvider);
    final currentMember = ref.watch(currentFamilyMemberProvider).asData?.value;
    final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
    final role = kingdom?.membershipRole ?? currentMember?.role;
    final canManage = role == 'guardian' && currentMember?.isActive == true;
    final canPropose = (role == 'adventurer' || role == 'mercenary') &&
        currentMember?.isActive == true;
    final canSubmitVoluntaryQuest = ref.watch(canSubmitVoluntaryQuestProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DashboardHomeButton(),
        title: const Text('Grand Registre des Missions'),
        actions: [
          IconButton(
            tooltip: canManage
                ? 'Initiatives à examiner'
                : canSubmitVoluntaryQuest
                    ? 'Mes initiatives'
                    : 'Aventurier niveau 10 requis',
            onPressed: canManage || canSubmitVoluntaryQuest
                ? () => context.go('/quest-requests')
                : null,
            icon: const Icon(Icons.volunteer_activism_outlined),
          ),
        ],
      ),
      body: questsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Erreur : $error'),
        ),
        data: (quests) {
          if (quests.isEmpty) {
            return const Center(
              child: Text('Aucune mission pour le moment.'),
            );
          }

          final activeQuests = quests
              .where((quest) => !quest.isCompletedForPeriod)
              .toList();
          final completedQuests = quests
              .where((quest) => quest.isCompletedForPeriod)
              .toList();

          Widget buildQuestCard(Quest quest) => QuestCard(
                key: ValueKey(quest.id),
                quest: quest,
                compactOnMobile: true,
                onSelfAssign: () async {
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
                            : 'Erreur : ${state.error}',
                      ),
                    ),
                  );
                },
                onEdit: canManage
                    ? () => showDialog(
                          context: context,
                          builder: (_) => QuestFormDialog(quest: quest),
                        )
                    : null,
                onAssign: canManage
                    ? () => showDialog(
                          context: context,
                          builder: (_) => AssignQuestDialog(quest: quest),
                        )
                    : null,
                onArchive: canManage
                    ? () async {
                        await ref
                            .read(updateQuestControllerProvider.notifier)
                            .archiveQuest(quest.id);
                      }
                    : null,
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeQuests.isNotEmpty) ...[
                const _QuestSectionHeader(
                  title: 'Quêtes actives',
                  icon: Icons.explore_outlined,
                ),
                for (final quest in activeQuests) ...[
                  buildQuestCard(quest),
                  const SizedBox(height: 12),
                ],
              ],
              if (completedQuests.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _QuestSectionHeader(
                  title: 'Terminées pour cette période',
                  icon: Icons.check_circle_outline,
                ),
                for (final quest in completedQuests) ...[
                  buildQuestCard(quest),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const QuestFormDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle mission'),
            )
          : canPropose
              ? FloatingActionButton.extended(
                  onPressed: canSubmitVoluntaryQuest
                      ? () => showDialog<void>(
                            context: context,
                            builder: (_) => const VoluntaryQuestRequestDialog(),
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
    );
  }
}

class _QuestSectionHeader extends StatelessWidget {
  const _QuestSectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
