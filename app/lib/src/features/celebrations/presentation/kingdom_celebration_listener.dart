import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chronicles/domain/kingdom_legend_entry.dart';
import '../../chronicles/providers/chronicles_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/celebration_preferences.dart';

class KingdomCelebrationListener extends ConsumerStatefulWidget {
  const KingdomCelebrationListener({super.key});

  @override
  ConsumerState<KingdomCelebrationListener> createState() =>
      _KingdomCelebrationListenerState();
}

class _KingdomCelebrationListenerState
    extends ConsumerState<KingdomCelebrationListener> {
  bool _processing = false;
  String? _scheduledFingerprint;

  @override
  Widget build(BuildContext context) {
    ref.watch(kingdomLegendRealtimeProvider);
    final entries = ref.watch(kingdomLegendProvider).valueOrNull;
    final family = ref.watch(currentFamilyProvider).valueOrNull;
    final member = ref.watch(currentFamilyMemberProvider).valueOrNull;

    if (entries != null && family != null && member != null) {
      final fingerprint = entries
          .map(
            (entry) =>
                '${entry.id}:${entry.eventType}:${entry.status}:${entry.occurredAt.toIso8601String()}',
          )
          .join('|');
      if (_scheduledFingerprint != fingerprint) {
        _scheduledFingerprint = fingerprint;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(
            _showPending(
              entries: entries,
              familyId: family.id,
              userId: member.userId,
              memberId: member.id,
            ),
          );
        });
      }
    }

    return const SizedBox.shrink();
  }

  Future<void> _showPending({
    required List<KingdomLegendEntry> entries,
    required String familyId,
    required String userId,
    required String memberId,
  }) async {
    if (_processing || !mounted) return;
    _processing = true;

    try {
      final seen = await CelebrationPreferences.seenIds(
        userId: userId,
        familyId: familyId,
      );
      final oldestAllowed = DateTime.now().toUtc().subtract(
            const Duration(days: 30),
          );
      final pending = entries.where((entry) {
        if (_wasCelebrationSeen(seen, entry) ||
            entry.occurredAt.isBefore(oldestAllowed)) {
          return false;
        }
        if (entry.id == 'member:$memberId') return false;
        return _kindFor(entry) != null;
      }).toList()
        ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));

      for (final entry in pending.skip(3)) {
        await CelebrationPreferences.markSeen(
          userId: userId,
          familyId: familyId,
          eventId: _celebrationIdFor(entry),
        );
      }

      for (final entry in pending.take(3).toList().reversed) {
        if (!mounted) break;
        await CelebrationPreferences.markSeen(
          userId: userId,
          familyId: familyId,
          eventId: _celebrationIdFor(entry),
        );
        if (!mounted) break;
        await showKingdomCelebration(context: context, entry: entry);
      }
    } finally {
      _processing = false;
    }
  }
}

enum _CelebrationKind { heroArrival, bossDefeated, rewardUnlocked }

String _celebrationIdFor(KingdomLegendEntry entry) =>
    '${entry.id}:${entry.eventType}:${entry.status}';

bool _wasCelebrationSeen(
  Set<String> seen,
  KingdomLegendEntry entry,
) {
  if (seen.contains(_celebrationIdFor(entry))) return true;

  // Before event-specific fingerprints, arrivals and boss victories were
  // stored with the row id only. Keep those memories without letting a
  // previously approved reward hide its later unlock celebration.
  return entry.category != 'reward' && seen.contains(entry.id);
}

_CelebrationKind? _kindFor(KingdomLegendEntry entry) {
  if (entry.category == 'member' &&
      entry.eventType == 'adventurer_joined' &&
      entry.status == 'active') {
    return _CelebrationKind.heroArrival;
  }
  if (entry.category == 'boss' && entry.status == 'defeated') {
    return _CelebrationKind.bossDefeated;
  }
  if (entry.category == 'reward' &&
      entry.eventType == 'reward_unlocked' &&
      entry.status == 'unlocked') {
    return _CelebrationKind.rewardUnlocked;
  }
  return null;
}

Future<void> showKingdomCelebration({
  required BuildContext context,
  required KingdomLegendEntry entry,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer la célébration',
    barrierColor: const Color(0xCC080716),
    transitionDuration: const Duration(milliseconds: 650),
    pageBuilder: (_, __, ___) => _CelebrationDialog(entry: entry),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
            scale: Tween(begin: 0.78, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _CelebrationDialog extends StatefulWidget {
  const _CelebrationDialog({required this.entry});

  final KingdomLegendEntry entry;

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    unawaited(_playFanfare());
  }

  Future<void> _playFanfare() async {
    try {
      await _player.setVolume(0.42);
      await _player.play(AssetSource('audio/celebration_fanfare.wav'));
    } catch (_) {
      // The celebration remains usable when autoplay is blocked.
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _CelebrationPresentation.from(widget.entry);
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 520, maxHeight: size.height * 0.9),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE7C873),
                  Color(0xFF6B55B8),
                  Color(0xFFE7C873)
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x886B55B8), blurRadius: 36, spreadRadius: 4),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                color: const Color(0xFF111027),
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      presentation.eyebrow,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE7C873),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) => Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A2455),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE7C873).withValues(
                                alpha: 0.28 + _glowController.value * 0.34,
                              ),
                              blurRadius: 22 + _glowController.value * 22,
                              spreadRadius: 2 + _glowController.value * 7,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(presentation.emoji,
                            style: const TextStyle(fontSize: 48)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      presentation.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      presentation.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFD8D2ED), fontSize: 16, height: 1.4),
                    ),
                    if (presentation.details.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: presentation.details
                            .map((detail) => Chip(label: Text(detail)))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE7C873),
                        foregroundColor: const Color(0xFF171126),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(presentation.actionLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CelebrationPresentation {
  const _CelebrationPresentation({
    required this.eyebrow,
    required this.emoji,
    required this.title,
    required this.body,
    required this.details,
    required this.actionLabel,
  });

  factory _CelebrationPresentation.from(KingdomLegendEntry entry) {
    final metadata = entry.metadata;
    switch (_kindFor(entry)!) {
      case _CelebrationKind.heroArrival:
        return _CelebrationPresentation(
          eyebrow: 'UN NOUVEAU HÉROS PARAÎT',
          emoji: '🧭',
          title: metadata['member_name'] as String? ?? entry.title,
          body:
              'Les portes du Royaume s’ouvrent. Une nouvelle légende rejoint désormais la guilde.',
          details: [
            'Aventurier',
            'Niveau ${metadata['level'] ?? 1}',
            '${metadata['xp'] ?? 0} XP',
          ],
          actionLabel: 'Bienvenue dans la guilde !',
        );
      case _CelebrationKind.bossDefeated:
        return _CelebrationPresentation(
          eyebrow: 'VICTOIRE DU ROYAUME',
          emoji: '🐉',
          title: entry.title,
          body:
              'Le Boss est vaincu ! Les Chroniques retiendront les héros qui ont combattu côte à côte.',
          details: [
            if ((metadata['element'] as String?)?.isNotEmpty == true)
              'Élément ${metadata['element']}',
            if ((metadata['special_item'] as String?)?.isNotEmpty == true)
              'Objet : ${metadata['special_item']}',
          ],
          actionLabel: 'Célébrer la victoire',
        );
      case _CelebrationKind.rewardUnlocked:
        return _CelebrationPresentation(
          eyebrow: 'RÉCOMPENSE DÉBLOQUÉE',
          emoji: '🎁',
          title: entry.title,
          body:
              'Le Royaume a rempli cet objectif collectif. Un Gardien peut maintenant remettre la récompense aux héros.',
          details: [
            if (metadata['guardian_quest_count'] != null)
              '${metadata['completed_quest_count'] ?? metadata['guardian_quest_count']}/${metadata['guardian_quest_count']} quêtes accomplies',
            if ((metadata['boss_theme'] as String?)?.isNotEmpty == true)
              'Boss vaincu : ${metadata['boss_theme']}',
          ],
          actionLabel: 'Découvrir la récompense',
        );
    }
  }

  final String eyebrow;
  final String emoji;
  final String title;
  final String body;
  final List<String> details;
  final String actionLabel;
}
