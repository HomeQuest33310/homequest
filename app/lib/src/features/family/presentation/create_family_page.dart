import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/family_provider.dart';

class CreateFamilyPage extends ConsumerStatefulWidget {
  const CreateFamilyPage({super.key});

  @override
  ConsumerState<CreateFamilyPage> createState() => _CreateFamilyPageState();
}

class _CreateFamilyPageState extends ConsumerState<CreateFamilyPage> {
  final _familyNameController = TextEditingController();
  final _kingdomNameController = TextEditingController();
  final _domainNameController = TextEditingController();

  @override
  void dispose() {
    _familyNameController.dispose();
    _kingdomNameController.dispose();
    _domainNameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final familyName = _familyNameController.text.trim();
    final kingdomName = _kingdomNameController.text.trim();
    final domainName = _domainNameController.text.trim();

    if (familyName.isEmpty || kingdomName.isEmpty || domainName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tous les champs sont nécessaires.')),
      );
      return;
    }

    await ref.read(createFamilyControllerProvider.notifier).createFamily(
          familyName: familyName,
          kingdomName: kingdomName,
          primaryDomainName: domainName,
        );

    final state = ref.read(createFamilyControllerProvider);
    if (!mounted) return;

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${state.error}')),
      );
      return;
    }

    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createFamilyControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🏰 Bienvenue dans HomeQuest',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Commençons votre aventure familiale.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _familyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la famille',
                        hintText: 'Famille Martin',
                        prefixIcon: Icon(Icons.groups),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _kingdomNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du royaume',
                        hintText: 'Le Royaume d’Émeraude',
                        prefixIcon: Icon(Icons.castle),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _domainNameController,
                      decoration: const InputDecoration(
                        labelText: 'Domaine principal',
                        hintText: 'Le Manoir des Aventuriers',
                        prefixIcon: Icon(Icons.home),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isLoading ? null : _create,
                      icon: const Icon(Icons.auto_awesome),
                      label: isLoading
                          ? const Text('Création du royaume...')
                          : const Text('Créer mon Royaume'),
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
