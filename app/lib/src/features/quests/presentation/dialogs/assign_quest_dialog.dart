import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/providers/family_members_provider.dart';
import '../../domain/quest.dart';
import '../../providers/quests_provider.dart';

class AssignQuestDialog extends ConsumerStatefulWidget {
  const AssignQuestDialog({
    super.key,
    required this.quest,
  });

  final Quest quest;

  @override
  ConsumerState<AssignQuestDialog> createState() => _AssignQuestDialogState();
}

class _AssignQuestDialogState extends ConsumerState<AssignQuestDialog> {
  String? _selectedMemberId;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(currentFamilyMembersProvider);
    final assignState = ref.watch(assignQuestControllerProvider);

    return AlertDialog(
      title: const Text('Assigner cette mission'),
      content: SizedBox(
        width: 420,
        child: membersAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text('Erreur : $error'),
          data: (members) {
            if (members.isEmpty) {
              return const Text('Aucun aventurier disponible.');
            }

            _selectedMemberId ??= members.first.id;

            return RadioGroup<String>(
              groupValue: _selectedMemberId,
              onChanged: (value) {
                setState(() => _selectedMemberId = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: members
                    .map(
                      (member) => RadioListTile<String>(
                        value: member.id,
                        title: Text(member.displayName),
                        subtitle: Text(member.role),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              assignState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: assignState.isLoading ? null : _assign,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Assigner'),
        ),
      ],
    );
  }

  Future<void> _assign() async {
    if (_selectedMemberId == null) return;

    await ref.read(assignQuestControllerProvider.notifier).assignQuest(
          questId: widget.quest.id,
          memberId: _selectedMemberId!,
        );

    if (!mounted) return;

    final state = ref.read(assignQuestControllerProvider);

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${state.error}')),
      );
      return;
    }

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mission assignée.')),
    );
  }
}
