import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domains/domain/domain.dart';
import '../domain/family_invitation.dart';
import '../providers/family_invitations_provider.dart';

class InviteMemberDialog extends ConsumerStatefulWidget {
  const InviteMemberDialog({
    required this.domains,
    super.key,
  });

  final List<Domain> domains;

  @override
  ConsumerState<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _role = 'adventurer';
  String _scope = 'kingdom';
  String? _domainId;
  double _duration = 7;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(familyInvitationsControllerProvider);
    final isMercenary = _role == 'mercenary';

    return AlertDialog(
      title: const Text('Inviter un membre'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Saisissez une adresse e-mail valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(
                      value: 'adventurer',
                      child: Text('Aventurier permanent'),
                    ),
                    DropdownMenuItem(
                      value: 'mercenary',
                      child: Text('Mercenaire temporaire'),
                    ),
                  ],
                  onChanged: state.isLoading
                      ? null
                      : (value) => setState(() {
                            _role = value ?? 'adventurer';
                            if (_role == 'adventurer') {
                              _scope = 'kingdom';
                              _domainId = null;
                            }
                          }),
                ),
                if (isMercenary) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _scope,
                    decoration: const InputDecoration(
                      labelText: 'Périmètre de mission',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'kingdom',
                        child: Text('Tout le royaume'),
                      ),
                      DropdownMenuItem(
                        value: 'domain',
                        child: Text('Un domaine précis'),
                      ),
                    ],
                    onChanged: state.isLoading
                        ? null
                        : (value) => setState(() {
                              _scope = value ?? 'kingdom';
                              if (_scope == 'kingdom') _domainId = null;
                            }),
                  ),
                  if (_scope == 'domain') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _domainId,
                      decoration: const InputDecoration(labelText: 'Domaine'),
                      items: widget.domains
                          .map(
                            (domain) => DropdownMenuItem(
                              value: domain.id,
                              child: Text(domain.name),
                            ),
                          )
                          .toList(),
                      validator: (value) => _scope == 'domain' && value == null
                          ? 'Choisissez un domaine.'
                          : null,
                      onChanged: state.isLoading
                          ? null
                          : (value) => setState(() => _domainId = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.schedule),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Accès pendant ${_duration.round()} jours',
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _duration,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '${_duration.round()} jours',
                    onChanged: state.isLoading
                        ? null
                        : (value) => setState(() => _duration = value),
                  ),
                ],
                if (state.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Erreur : ${state.error}',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: state.isLoading ? null : _submit,
          icon: state.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Créer l’invitation'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final FamilyInvitation? invitation =
        await ref.read(familyInvitationsControllerProvider.notifier).invite(
              email: _emailController.text.trim(),
              role: _role,
              membershipScope: _scope,
              domainId: _scope == 'domain' ? _domainId : null,
              expiresInDays: _role == 'mercenary' ? _duration.round() : 7,
            );

    if (invitation != null && mounted) Navigator.pop(context, invitation);
  }
}
