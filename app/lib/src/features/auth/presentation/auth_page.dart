import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/links/invitation_link.dart';
import '../../../core/links/pending_invitation_store.dart';
import '../../family/providers/family_provider.dart';
import '../providers/auth_provider.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({this.invitationToken, super.key});

  final String? invitationToken;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isSignUp;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // An invitation is most often opened by an account that Supabase has
    // already created or confirmed. Start on sign-in while keeping sign-up
    // available for genuinely new adventurers.
    _isSignUp = widget.invitationToken == null;
    final invitationToken = widget.invitationToken;
    if (invitationToken != null && invitationToken.isNotEmpty) {
      unawaited(_rememberInvitation(invitationToken));
    }
  }

  Future<void> _rememberInvitation(String token) async {
    await PendingInvitationStore.save(token);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        (_isSignUp && displayName.isEmpty)) {
      _setError('Tous les champs visibles sont nécessaires.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);

      if (_isSignUp) {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': displayName},
        );

        final user = response.user;
        if (user == null) {
          throw const AuthException(
            'Compte créé, mais aucune session active. Vérifiez la confirmation email dans Supabase.',
          );
        }

        await supabase.from('profiles').upsert({
          'id': user.id,
          'display_name': displayName,
          'avatar_key': 'default_adventurer',
        });
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;
      ref.invalidate(currentFamilyProvider);
      ref.invalidate(authStateProvider);
      final invitationToken = widget.invitationToken;
      if (invitationToken != null && invitationToken.isNotEmpty && mounted) {
        context.go(InvitationLink.appLocation(invitationToken));
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Erreur : $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                    const Text(
                      '📖 Les Chroniques de HomeQuest',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp
                          ? 'Inscris ton nom dans le Grand Registre des Aventuriers.'
                          : 'Rouvre les portes de ton royaume.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_isSignUp) ...[
                      TextField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom aventurier',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: Icon(_isSignUp ? Icons.auto_awesome : Icons.login),
                      label: _isLoading
                          ? const Text('Ouverture des Chroniques...')
                          : Text(_isSignUp
                              ? 'Créer mon aventurier'
                              : 'Se connecter'),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                      child: Text(
                        _isSignUp
                            ? 'J’ai déjà un aventurier'
                            : 'Créer un nouvel aventurier',
                      ),
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
