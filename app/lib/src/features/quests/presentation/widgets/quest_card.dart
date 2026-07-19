import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/quest.dart';
import '../../domain/quest_suggestion.dart';

class QuestCard extends StatefulWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.onEdit,
    required this.onAssign,
    required this.onArchive,
    this.onSelfAssign,
    this.compactOnMobile = false,
  });

  final Quest quest;
  final VoidCallback? onEdit;
  final VoidCallback? onAssign;
  final VoidCallback? onArchive;
  final VoidCallback? onSelfAssign;
  final bool compactOnMobile;

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = widget.compactOnMobile && constraints.maxWidth < 600;
        final showDetails = !compact || _expanded;

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: questLocationBorderColor(widget.quest.regionKey),
              width: 2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummary(context, compact: compact),
                if (compact && widget.onSelfAssign != null) ...[
                  const SizedBox(height: 10),
                  _QuestSelfAssignButton(
                    availableFrom: widget.quest.availableFrom,
                    onPressed: widget.onSelfAssign!,
                    fullWidth: true,
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: showDetails
                      ? _buildDetails(
                          context,
                          includeSelfAssign: !compact,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary(
    BuildContext context, {
    required bool compact,
  }) {
    final quest = widget.quest;
    final theme = Theme.of(context);
    if (!compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${quest.emoji} ${quest.title}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text('Tâche réelle : ${quest.realTask}'),
        ],
      );
    }

    return Tooltip(
      message: _expanded
          ? 'Double-appui pour réduire'
          : 'Double-appui pour afficher les détails',
      child: InkWell(
        onDoubleTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: questLocationBorderColor(quest.regionKey)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  quest.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quest.realTask,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _expanded ? 'Réduire la quête' : 'Agrandir la quête',
                onPressed: _toggleExpanded,
                icon: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context, {
    required bool includeSelfAssign,
  }) {
    final quest = widget.quest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((quest.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(quest.description!),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatBadge(
              icon: Icons.location_on_outlined,
              label: questLocationLabels[quest.regionKey] ??
                  quest.regionKey ??
                  'Autre lieu',
            ),
            _StatBadge(
              icon: Icons.auto_awesome,
              label: quest.element,
            ),
            _StatBadge(
              icon: Icons.signal_cellular_alt,
              label: List.filled(quest.difficulty, '⭐').join(),
            ),
          ],
        ),
        if (quest.skillRewards.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quest.skillRewards
                .map(
                  (reward) => Chip(
                    avatar: Text(reward.icon),
                    label: Text(
                      '${reward.name.isEmpty ? reward.skillId : reward.name} '
                      '+${reward.xpReward}',
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        _AssignmentBadge(assignees: quest.assignees),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatBadge(icon: Icons.star, label: '${quest.xpReward} XP'),
            _StatBadge(
              icon: Icons.monetization_on,
              label: '${quest.goldReward} Or',
            ),
            _StatBadge(
              icon: Icons.gps_fixed,
              label: '${quest.bossDamage} dégâts',
            ),
            _StatBadge(icon: Icons.repeat, label: quest.frequencyLabel),
            if (quest.availableFrom != null)
              _StatBadge(
                icon: Icons.schedule,
                label: quest.isAvailableNow
                    ? 'Disponible maintenant'
                    : 'Disponible le '
                        '${DateFormat('dd/MM/yyyy à HH:mm').format(quest.availableFrom!.toLocal())}',
              ),
            _StatBadge(
              icon: quest.requiresApproval
                  ? Icons.fact_check_outlined
                  : Icons.bolt_outlined,
              label: quest.requiresApproval
                  ? 'Validation requise'
                  : 'Validation automatique',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (includeSelfAssign && widget.onSelfAssign != null)
              _QuestSelfAssignButton(
                availableFrom: quest.availableFrom,
                onPressed: widget.onSelfAssign!,
              ),
            if (widget.onEdit != null)
              FilledButton.tonalIcon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
              ),
            if (widget.onAssign != null)
              OutlinedButton.icon(
                onPressed: widget.onAssign,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Assigner'),
              ),
            if (widget.onArchive != null)
              OutlinedButton.icon(
                onPressed: widget.onArchive,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archiver'),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuestSelfAssignButton extends StatefulWidget {
  const _QuestSelfAssignButton({
    required this.availableFrom,
    required this.onPressed,
    this.fullWidth = false,
  });

  final DateTime? availableFrom;
  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  State<_QuestSelfAssignButton> createState() => _QuestSelfAssignButtonState();
}

class _QuestSelfAssignButtonState extends State<_QuestSelfAssignButton> {
  Timer? _availabilityTimer;

  bool get _isAvailable {
    final availableFrom = widget.availableFrom;
    return availableFrom == null || !DateTime.now().isBefore(availableFrom);
  }

  @override
  void initState() {
    super.initState();
    _scheduleAvailabilityRefresh();
  }

  @override
  void didUpdateWidget(covariant _QuestSelfAssignButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableFrom != widget.availableFrom) {
      _scheduleAvailabilityRefresh();
    }
  }

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    super.dispose();
  }

  void _scheduleAvailabilityRefresh() {
    _availabilityTimer?.cancel();
    final availableFrom = widget.availableFrom;
    if (availableFrom == null) return;
    final delay = availableFrom.difference(DateTime.now());
    if (delay <= Duration.zero) return;
    _availabilityTimer = Timer(delay, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = _isAvailable;
    final availableFrom = widget.availableFrom?.toLocal();
    return SizedBox(
      width: widget.fullWidth ? double.infinity : null,
      child: FilledButton.icon(
        onPressed: available ? widget.onPressed : null,
        icon: Icon(
          available ? Icons.back_hand_outlined : Icons.schedule,
        ),
        label: Text(
          available
              ? 'Prendre cette mission'
              : 'Disponible à partir du '
                  '${DateFormat('dd/MM/yyyy à HH:mm').format(availableFrom!)}',
        ),
      ),
    );
  }
}

Color questLocationBorderColor(String? regionKey) {
  return switch (regionKey) {
    'kitchen' => const Color(0xFFF59E0B),
    'laundry' => const Color(0xFF6366F1),
    'bathroom' => const Color(0xFF06B6D4),
    'bedroom' => const Color(0xFF8B5CF6),
    'living_room' => const Color(0xFF10B981),
    'outdoor' => const Color(0xFF65A30D),
    'special_cooking' => const Color(0xFFF97316),
    'quick_daily' => const Color(0xFFEAB308),
    'family_group' => const Color(0xFFEC4899),
    'animal_care' => const Color(0xFF92400E),
    'home_routine' => const Color(0xFF0D9488),
    'vehicle' => const Color(0xFF64748B),
    'wellbeing' => const Color(0xFFDB2777),
    'community' => const Color(0xFF2563EB),
    _ => const Color(0xFF8B8B98),
  };
}

class _AssignmentBadge extends StatelessWidget {
  const _AssignmentBadge({required this.assignees});

  final List<QuestAssignee> assignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecruiting = assignees.isEmpty;
    final label = isRecruiting
        ? 'Recrutement · Mission libre'
        : 'Assignée à ${assignees.map((member) => member.displayName).join(', ')}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isRecruiting
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(
              isRecruiting ? Icons.campaign_outlined : Icons.people_outline,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
