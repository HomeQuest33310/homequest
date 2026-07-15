import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/links/invitation_link.dart';
import '../../../core/links/pending_invitation_store.dart';
import '../../auth/providers/auth_provider.dart';
import '../../opening/presentation/show_kingdom_arrival.dart';
import '../providers/family_invitations_provider.dart';
import '../providers/family_provider.dart';

class AcceptInvitationPage extends ConsumerStatefulWidget {
  const AcceptInvitationPage({required this.token, super.key});

  final String token;

  @override
  ConsumerState<AcceptInvitationPage> createState() =>
      _AcceptInvitationPageState();
}

class _AcceptInvitationPageState extends ConsumerState<AcceptInvitationPage> {
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    _rememberInvitation();
  }

  Future<void> _rememberInvitation() async {
    await PendingInvitationStore.save(widget.token);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(familyInvitationsControllerProvider);
    final requiresInitialPassword = _requiresInitialPassword(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre le Royaume')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.castle, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Une guilde vous invite à participer à son aventure.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    if (user == null) ...[
                      const Text(
                        'Créez votre aventurier ou connectez-vous avec '
                        'l’adresse e-mail invitée. Votre invitation sera '
                        'conservée pendant cette étape.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go(
                          InvitationLink.authLocation(widget.token),
                        ),
                        child: const Text('Continuer'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _ignoreInvitation,
                        child: const Text('Ignorer cette invitation'),
                      ),
                    ] else ...[
                      Text(
                        'Connecté avec ${user.email ?? 'votre compte'}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom d’aventurier (facultatif)',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: requiresInitialPassword
                              ? 'Créez votre mot de passe'
                              : 'Nouveau mot de passe (facultatif)',
                          helperText: requiresInitialPassword
                              ? 'Au moins 8 caractères pour protéger votre aventurier.'
                              : 'Laissez vide pour conserver votre mot de passe actuel.',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: state.isLoading ? null : _accept,
                        icon: state.isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Finaliser et rejoindre'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: state.isLoading ? null : _ignoreInvitation,
                        child: const Text('Ignorer cette invitation'),
                      ),
                      if (_localError != null || state.hasError) ...[
                        const SizedBox(height: 12),
                        Text(
                          _localError ??
                              'Impossible de rejoindre le Royaume : ${state.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _localError = null);
    final password = _passwordController.text;
    final user = ref.read(currentUserProvider);
    if (_requiresInitialPassword(user) && password.isEmpty) {
      setState(() {
        _localError =
            'Créez un mot de passe avant de rejoindre le Royaume.';
      });
      return;
    }
    if (password.isNotEmpty && password.length < 8) {
      setState(() {
        _localError = 'Le mot de passe doit contenir au moins 8 caractères.';
      });
      return;
    }

    try {
      final client = ref.read(supabaseProvider);
      final invitation = await ref
          .read(familyRepositoryProvider)
          .getInvitationByToken(widget.token);
      final displayName = _displayNameController.text.trim();
      if (password.isNotEmpty) {
        await client.auth.updateUser(UserAttributes(password: password));
      }
      if (displayName.isNotEmpty) {
        final userId = client.auth.currentUser!.id;
        await client.from('profiles').upsert({
          'id': userId,
          'display_name': displayName,
          'avatar_key': 'default_adventurer',
        });
      }

      final success = await ref
          .read(familyInvitationsControllerProvider.notifier)
          .accept(widget.token);
      if (!mounted) return;
      if (success) {
        await PendingInvitationStore.clear();
        if (!mounted) return;
        ref.invalidate(pendingInvitationTokenProvider);
        if (invitation != null) {
          await showKingdomArrivalIfNeeded(
            context: context,
            kingdomId: invitation.kingdomId,
          );
        }
        if (mounted) context.go('/');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _localError = error.message);
    } catch (error) {
      if (mounted) setState(() => _localError = 'Erreur : $error');
    }
  }

  Future<void> _ignoreInvitation() async {
    await PendingInvitationStore.clear();
    ref.invalidate(pendingInvitationTokenProvider);
    if (mounted) context.go('/');
  }

  bool _requiresInitialPassword(User? user) {
    final invitationToken = user?.userMetadata?['invitation_token']?.toString();
    return invitationToken != null && invitationToken == widget.token;
  }
}
