import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/family_invitations_provider.dart';

class DeclineInvitationPage extends ConsumerStatefulWidget {
  const DeclineInvitationPage({required this.token, super.key});

  final String token;

  @override
  ConsumerState<DeclineInvitationPage> createState() =>
      _DeclineInvitationPageState();
}

class _DeclineInvitationPageState
    extends ConsumerState<DeclineInvitationPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decline());
  }

  Future<void> _decline() async {
    final success = await ref
        .read(familyInvitationsControllerProvider.notifier)
        .decline(widget.token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!success) {
        _error = 'Cette invitation est déjà utilisée ou n’est plus valide.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation HomeQuest')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _error == null
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 64,
                          color: _error == null
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error ?? 'Invitation refusée.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Retour à HomeQuest'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
