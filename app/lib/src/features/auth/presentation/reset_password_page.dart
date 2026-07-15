import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _passwordController.text;
    final confirmation = _confirmationController.text;

    if (password.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (password != confirmation) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseProvider);
      await client.auth.updateUser(UserAttributes(password: password));
      await client.auth.signOut();
      ref.read(passwordRecoveryProvider.notifier).state = false;
      if (mounted) context.go('/');
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Erreur : $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    await ref.read(supabaseProvider).auth.signOut();
    ref.read(passwordRecoveryProvider.notifier).state = false;
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    const Icon(Icons.key_rounded, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'Forger un nouveau mot de passe',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choisissez une nouvelle clé secrète pour protéger votre aventurier.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmationController,
                      obscureText: true,
                      autocorrect: false,
                      onSubmitted: (_) => _isLoading ? null : _save(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isLoading ? 'Mise à jour...' : 'Enregistrer et me reconnecter',
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _cancel,
                      child: const Text('Annuler'),
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
