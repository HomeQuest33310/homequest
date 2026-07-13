import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/family_invitations_provider.dart';

class AcceptInvitationPage extends ConsumerWidget {
  const AcceptInvitationPage({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(familyInvitationsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre le royaume')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      'Connectez-vous avec l’adresse e-mail invitée, puis '
                      'ouvrez à nouveau ce lien.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/auth'),
                      child: const Text('Se connecter'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed:
                          state.isLoading ? null : () => _accept(context, ref),
                      icon: state.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Accepter l’invitation'),
                    ),
                    if (state.hasError) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Impossible de rejoindre le royaume : ${state.error}',
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
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(familyInvitationsControllerProvider.notifier)
        .accept(token);
    if (!context.mounted) return;
    if (success) context.go('/');
  }
}
