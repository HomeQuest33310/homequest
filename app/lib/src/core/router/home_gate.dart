import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../links/pending_invitation_store.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/family/presentation/accept_invitation_page.dart';
import '../../features/family/presentation/create_family_page.dart';
import '../../features/family/presentation/family_dashboard_page.dart';
import '../../features/kingdom/providers/kingdom_provider.dart';
import '../../features/opening/presentation/first_launch_gate.dart';

class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider);
    final user = ref.watch(currentUserProvider);
    final pendingInvitation = ref.watch(pendingInvitationTokenProvider);

    if (pendingInvitation.isLoading) {
      return const _LoadingPage(message: 'Recherche de votre invitation...');
    }

    final invitationToken = pendingInvitation.asData?.value;

    if (user == null) {
      return FirstLaunchGate(
        child: AuthPage(invitationToken: invitationToken),
      );
    }

    if (invitationToken != null && invitationToken.isNotEmpty) {
      return AcceptInvitationPage(token: invitationToken);
    }

    // The gate only decides whether the user owns at least one kingdom.
    // It must not depend on the currently selected kingdom: changing kingdoms
    // would otherwise alternate between this gate and the dashboard while the
    // selected family's data is reloading.
    final kingdomsAsync = ref.watch(availableKingdomsProvider);

    return kingdomsAsync.when(
      loading: () => const _LoadingPage(message: 'Ouverture des Chroniques...'),
      error: (error, stackTrace) => _ErrorPage(
        message: 'Impossible de charger le royaume.',
        details: error.toString(),
        onRetry: () => ref.invalidate(availableKingdomsProvider),
      ),
      data: (kingdoms) {
        if (kingdoms.isEmpty) {
          return const CreateFamilyPage();
        }
        return const FamilyDashboardPage();
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({
    required this.message,
    required this.details,
    required this.onRetry,
  });

  final String message;
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      details,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
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
