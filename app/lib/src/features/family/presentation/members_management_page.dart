import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../domains/domain/domain.dart';
import '../../domains/providers/domains_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../../../core/links/invitation_link.dart';
import '../domain/family_invitation.dart';
import '../domain/family_member.dart';
import '../providers/family_invitations_provider.dart';
import '../providers/family_members_provider.dart';
import '../providers/family_provider.dart';
import 'invite_member_dialog.dart';

class MembersManagementPage extends ConsumerWidget {
  const MembersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final kingdom = ref.watch(currentKingdomProvider).asData?.value;
    final members = ref.watch(currentFamilyMembersProvider);
    final invitations = ref.watch(currentFamilyInvitationsProvider);
    final domains = ref.watch(currentFamilyDomainsProvider).asData?.value ??
        const <Domain>[];
    final userId = ref.watch(currentUserProvider)?.id;
    FamilyMember? currentMember;
    for (final member in members.asData?.value ?? const <FamilyMember>[]) {
      if (member.userId == userId) {
        currentMember = member;
        break;
      }
    }
    final canManage = kingdom?.membershipRole == 'guardian' &&
        currentMember?.isActive == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membres du royaume'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Inviter',
              onPressed: () => _showInviteDialog(
                context,
                ref,
                domains,
                canInviteGuardian: family?.ownerId == userId,
              ),
              icon: const Icon(Icons.person_add),
            ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showInviteDialog(
                context,
                ref,
                domains,
                canInviteGuardian: family?.ownerId == userId,
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Inviter'),
            )
          : null,
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: 'Impossible de charger les membres : $error',
          onRetry: () => ref.invalidate(currentFamilyMembersProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentFamilyMembersProvider);
            ref.invalidate(currentFamilyInvitationsProvider);
            await ref.read(currentFamilyMembersProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('Aventuriers',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (final member in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MemberCard(
                    member: member,
                    isOwner: member.userId == family?.ownerId,
                    canManage: canManage && member.userId != userId,
                    onRoleChanged: (role) =>
                        _changeRole(context, ref, member, role),
                    onDeactivate: () => _deactivate(context, ref, member),
                  ),
                ),
              if (canManage) ...[
                const SizedBox(height: 16),
                Text(
                  'Invitations en attente',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                invitations.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('Invitations indisponibles : $error'),
                  data: (items) => items.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Aucune invitation en attente.'),
                          ),
                        )
                      : Column(
                          children: [
                            for (final invitation in items)
                              _InvitationCard(
                                invitation: invitation,
                                onCopy: () =>
                                    _copyInviteLink(context, invitation),
                                onCancel: () => _cancelInvitation(
                                  context,
                                  ref,
                                  invitation,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(
    BuildContext context,
    WidgetRef ref,
    List<Domain> domains, {
    required bool canInviteGuardian,
  }) async {
    final invitation = await showDialog<FamilyInvitation>(
      context: context,
      builder: (_) => InviteMemberDialog(
        domains: domains,
        canInviteGuardian: canInviteGuardian,
      ),
    );
    if (invitation != null && context.mounted) {
      await _copyInviteLink(context, invitation);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              invitation.emailSent
                  ? 'Invitation envoyée par e-mail et lien copié.'
                  : 'Invitation créée. Le lien a été copié pour un partage manuel.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
    String role,
  ) async {
    await ref.read(familyMembersControllerProvider.notifier).changeRole(
          memberId: member.id,
          newRole: role,
        );
    if (context.mounted) _showControllerResult(context, ref);
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Désactiver ce membre ?'),
        content: Text('${member.displayName} perdra l’accès au royaume.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(familyMembersControllerProvider.notifier)
        .deactivateMember(member.id);
    if (context.mounted) _showControllerResult(context, ref);
  }

  void _showControllerResult(BuildContext context, WidgetRef ref) {
    final state = ref.read(familyMembersControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.hasError ? 'Erreur : ${state.error}' : 'Membre mis à jour.',
        ),
      ),
    );
  }

  Future<void> _cancelInvitation(
    BuildContext context,
    WidgetRef ref,
    FamilyInvitation invitation,
  ) async {
    final success = await ref
        .read(familyInvitationsControllerProvider.notifier)
        .cancel(invitation.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Invitation annulée.' : 'Annulation impossible.'),
        ),
      );
    }
  }

  Future<void> _copyInviteLink(
    BuildContext context,
    FamilyInvitation invitation,
  ) async {
    final link = InvitationLink.build(invitation.token).toString();
    await Clipboard.setData(ClipboardData(text: link));
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isOwner,
    required this.canManage,
    required this.onRoleChanged,
    required this.onDeactivate,
  });

  final FamilyMember member;
  final bool isOwner;
  final bool canManage;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onDeactivate;

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
                child: Text(
                  member.displayName.isEmpty
                      ? '?'
                      : member.displayName.characters.first.toUpperCase(),
                ),
              ),
              title: Text(member.displayName),
              subtitle: Text(_roleLabel(member.role)),
              trailing:
                  isOwner ? const Chip(label: Text('Propriétaire')) : null,
            ),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Niveau ${member.level}')),
                Chip(label: Text('${member.xp} XP')),
                Chip(label: Text('${member.gold} or')),
                if (member.role == 'mercenary')
                  Chip(
                    label: Text(
                      member.membershipScope == 'domain'
                          ? 'Domaine limité'
                          : 'Royaume entier',
                    ),
                  ),
              ],
            ),
            if (canManage) ...[
              const Divider(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (member.role != 'guardian')
                    FilledButton.tonalIcon(
                      onPressed: () => onRoleChanged('guardian'),
                      icon: const Icon(Icons.shield),
                      label: const Text('Promouvoir Gardien'),
                    ),
                  if (member.role == 'guardian')
                    OutlinedButton.icon(
                      onPressed: () => onRoleChanged('adventurer'),
                      icon: const Icon(Icons.explore),
                      label: const Text('Passer Aventurier'),
                    ),
                  OutlinedButton.icon(
                    onPressed: onDeactivate,
                    icon: const Icon(Icons.person_off),
                    label: const Text('Désactiver'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _roleLabel(String role) => switch (role) {
        'guardian' => 'Gardien',
        'mercenary' => 'Mercenaire',
        _ => 'Aventurier',
      };
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onCopy,
    required this.onCancel,
  });

  final FamilyInvitation invitation;
  final VoidCallback onCopy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mail_outline),
        title: Text(invitation.email),
        subtitle: Text(
          '${_MemberCard._roleLabel(invitation.role)} · '
          'expire le ${MaterialLocalizations.of(context).formatShortDate(invitation.expiresAt)}',
        ),
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: 'Copier le lien',
              onPressed: onCopy,
              icon: const Icon(Icons.link),
            ),
            IconButton(
              tooltip: 'Annuler',
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
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
