import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/env.dart';
import '../../shared/widgets/hq_page.dart';
import 'auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final displayNameController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    displayNameController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => isLoading = true);
    try {
      await action();
      if (mounted) context.go('/create-family');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HqPage(
      title: 'HomeQuest',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bienvenue dans votre royaume familial.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (!Env.hasSupabaseConfig)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Supabase n’est pas encore configuré. Lancez Flutter avec --dart-define SUPABASE_URL=... et SUPABASE_ANON_KEY=...',
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: displayNameController,
            decoration: const InputDecoration(labelText: 'Nom d’aventurier'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isLoading || !Env.hasSupabaseConfig
                ? null
                : () => _run(() => ref.read(authControllerProvider).signInWithEmail(
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    )),
            child: const Text('Se connecter'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: isLoading || !Env.hasSupabaseConfig
                ? null
                : () => _run(() => ref.read(authControllerProvider).signUpWithEmail(
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      displayName: displayNameController.text.trim(),
                    )),
            child: const Text('Créer un compte'),
          ),
        ],
      ),
    );
  }
}
