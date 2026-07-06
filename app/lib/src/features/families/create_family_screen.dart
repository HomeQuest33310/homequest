import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/hq_page.dart';
import 'family_controller.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final familyNameController = TextEditingController();
  final kingdomNameController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    familyNameController.dispose();
    kingdomNameController.dispose();
    super.dispose();
  }

  Future<void> createFamily() async {
    setState(() => isLoading = true);
    try {
      await ref.read(familyControllerProvider).createFamily(
            familyName: familyNameController.text.trim(),
            kingdomName: kingdomNameController.text.trim(),
          );
      if (mounted) context.go('/dashboard');
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
      title: 'Créer une guilde',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Donnez un nom à votre famille et à votre royaume.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: familyNameController,
            decoration: const InputDecoration(labelText: 'Nom de la famille'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: kingdomNameController,
            decoration: const InputDecoration(labelText: 'Nom du royaume'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isLoading ? null : createFamily,
            child: const Text('Fonder le royaume'),
          ),
        ],
      ),
    );
  }
}
