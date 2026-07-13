import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/providers/family_members_provider.dart';
import '../../providers/quests_provider.dart';
import '../dialogs/assign_quest_dialog.dart';
import '../dialogs/quest_form_dialog.dart';
import '../widgets/quest_card.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(currentFamilyQuestsProvider);
    final currentMember = ref.watch(currentFamilyMemberProvider).asData?.value;
    final canManage = currentMember?.role == 'guardian';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grand Registre des Missions'),
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final quest = quests[index];

              return QuestCard(
                quest: quest,
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
              );
            },
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
          : null,
    );
  }
}
