import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../kingdom/domain/kingdom.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../domain/shopping_item.dart';
import '../providers/shopping_provider.dart';

class ShoppingPage extends ConsumerWidget {
  const ShoppingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(shoppingRealtimeProvider);
    final kingdoms = ref.watch(availableKingdomsProvider);
    final currentKingdom = ref.watch(currentKingdomProvider).valueOrNull;
    final items = ref.watch(currentShoppingItemsProvider);
    final controller = ref.watch(shoppingControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour au Royaume',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Ravitaillement'),
      ),
      floatingActionButton: currentKingdom == null
          ? null
          : FloatingActionButton.extended(
              onPressed: controller.isLoading
                  ? null
                  : () => _showAddItem(context, ref),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Ajouter'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentShoppingItemsProvider);
          await ref.read(currentShoppingItemsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _SupplyHeader(
              kingdoms: kingdoms.valueOrNull ?? const [],
              currentKingdom: currentKingdom,
              onChanged: (kingdomId) {
                if (kingdomId == null) return;
                ref.read(selectedKingdomIdProvider.notifier).state = kingdomId;
              },
            ),
            const SizedBox(height: 16),
            items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ShoppingError(
                error: error,
                onRetry: () => ref.invalidate(currentShoppingItemsProvider),
              ),
              data: (values) => _ShoppingSections(
                items: values,
                isLoading: controller.isLoading,
                onClaim: (item) => _perform(
                  context,
                  ref,
                  () => ref
                      .read(shoppingControllerProvider.notifier)
                      .claimItem(item.id),
                ),
                onPurchased: (item) => _perform(
                  context,
                  ref,
                  () => ref
                      .read(shoppingControllerProvider.notifier)
                      .markPurchased(item.id),
                ),
                onRestore: (item) => _perform(
                  context,
                  ref,
                  () => ref
                      .read(shoppingControllerProvider.notifier)
                      .restoreItem(item.id),
                ),
                onArchive: (item) => _perform(
                  context,
                  ref,
                  () => ref
                      .read(shoppingControllerProvider.notifier)
                      .archiveItem(item.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddItem(BuildContext context, WidgetRef ref) async {
    final request = await showDialog<_ShoppingRequest>(
      context: context,
      builder: (_) => const _AddShoppingItemDialog(),
    );
    if (request == null || !context.mounted) return;

    final success = await ref.read(shoppingControllerProvider.notifier).addItem(
          name: request.name,
          quantity: request.quantity,
          category: request.category,
          note: request.note,
        );
    if (!context.mounted) return;
    _showResult(context, ref, success, 'Article ajouté au ravitaillement.');
  }

  Future<void> _perform(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function() action,
  ) async {
    final success = await action();
    if (!context.mounted) return;
    _showResult(context, ref, success, 'Liste de ravitaillement mise à jour.');
  }

  void _showResult(
    BuildContext context,
    WidgetRef ref,
    bool success,
    String successMessage,
  ) {
    final error = ref.read(shoppingControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : 'Action impossible : $error'),
      ),
    );
  }
}

class _SupplyHeader extends StatelessWidget {
  const _SupplyHeader({
    required this.kingdoms,
    required this.currentKingdom,
    required this.onChanged,
  });

  final List<Kingdom> kingdoms;
  final Kingdom? currentKingdom;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🧺', style: TextStyle(fontSize: 38)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Réserves du foyer',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Text(
                        'Gardiens, Aventuriers et Mercenaires peuvent '
                        'préparer ensemble la prochaine expédition.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (kingdoms.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: currentKingdom?.id,
                decoration: const InputDecoration(
                  labelText: 'Royaume à ravitailler',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final kingdom in kingdoms)
                    DropdownMenuItem(
                      value: kingdom.id,
                      child: Text('${kingdom.icon} ${kingdom.name}'),
                    ),
                ],
                onChanged: onChanged,
              ),
            ] else if (currentKingdom != null) ...[
              const SizedBox(height: 12),
              Chip(
                  label:
                      Text('${currentKingdom!.icon} ${currentKingdom!.name}')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShoppingSections extends StatelessWidget {
  const _ShoppingSections({
    required this.items,
    required this.isLoading,
    required this.onClaim,
    required this.onPurchased,
    required this.onRestore,
    required this.onArchive,
  });

  final List<ShoppingItem> items;
  final bool isLoading;
  final ValueChanged<ShoppingItem> onClaim;
  final ValueChanged<ShoppingItem> onPurchased;
  final ValueChanged<ShoppingItem> onRestore;
  final ValueChanged<ShoppingItem> onArchive;

  @override
  Widget build(BuildContext context) {
    final needed = items.where((item) => !item.isPurchased).toList();
    final purchased = items.where((item) => item.isPurchased).toList();

    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La réserve est complète. Ajoutez un article quand le foyer '
            'a besoin d’être ravitaillé.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('À rapporter', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        if (needed.isEmpty) const Text('Tout a été rapporté au foyer.'),
        for (final item in needed)
          _ShoppingItemCard(
            item: item,
            isLoading: isLoading,
            onClaim: () => onClaim(item),
            onPurchased: () => onPurchased(item),
            onRestore: () => onRestore(item),
            onArchive: () => onArchive(item),
          ),
        if (purchased.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Déjà rapporté', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final item in purchased)
            _ShoppingItemCard(
              item: item,
              isLoading: isLoading,
              onClaim: () => onClaim(item),
              onPurchased: () => onPurchased(item),
              onRestore: () => onRestore(item),
              onArchive: () => onArchive(item),
            ),
        ],
      ],
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  const _ShoppingItemCard({
    required this.item,
    required this.isLoading,
    required this.onClaim,
    required this.onPurchased,
    required this.onRestore,
    required this.onArchive,
  });

  final ShoppingItem item;
  final bool isLoading;
  final VoidCallback onClaim;
  final VoidCallback onPurchased;
  final VoidCallback onRestore;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(item.isPurchased ? Icons.check : Icons.shopping_basket),
        ),
        title: Text(
          '${item.quantity} · ${item.name}',
          style: TextStyle(
            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [item.category, if (item.note?.isNotEmpty == true) item.note!]
              .join(' · '),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (item.isNeeded)
              IconButton(
                tooltip: 'Je m’en charge',
                onPressed: isLoading ? null : onClaim,
                icon: const Icon(Icons.volunteer_activism),
              ),
            if (!item.isPurchased)
              IconButton(
                tooltip: 'Article rapporté',
                onPressed: isLoading ? null : onPurchased,
                icon: const Icon(Icons.check_circle_outline),
              ),
            if (item.isPurchased)
              IconButton(
                tooltip: 'Remettre sur la liste',
                onPressed: isLoading ? null : onRestore,
                icon: const Icon(Icons.replay),
              ),
            PopupMenuButton<String>(
              enabled: !isLoading,
              onSelected: (value) {
                if (value == 'archive') onArchive();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'archive',
                  child: Text('Archiver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddShoppingItemDialog extends StatefulWidget {
  const _AddShoppingItemDialog();

  @override
  State<_AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<_AddShoppingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  String _category = 'Alimentation';

  static const _categories = [
    'Alimentation',
    'Hygiène',
    'Maison',
    'Animaux',
    'École',
    'Autre',
  ];

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter au ravitaillement'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Article'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Indiquez un article.'
                    : null,
              ),
              TextFormField(
                controller: _quantity,
                decoration: const InputDecoration(labelText: 'Quantité'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Indiquez une quantité.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) => setState(() => _category = value!),
              ),
              TextFormField(
                controller: _note,
                decoration:
                    const InputDecoration(labelText: 'Note facultative'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _ShoppingRequest(
                name: _name.text.trim(),
                quantity: _quantity.text.trim(),
                category: _category,
                note: _note.text.trim(),
              ),
            );
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _ShoppingRequest {
  const _ShoppingRequest({
    required this.name,
    required this.quantity,
    required this.category,
    required this.note,
  });

  final String name;
  final String quantity;
  final String category;
  final String note;
}

class _ShoppingError extends StatelessWidget {
  const _ShoppingError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Liste indisponible : $error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
