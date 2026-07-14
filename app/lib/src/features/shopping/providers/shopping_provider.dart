import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_members_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../data/shopping_repository.dart';
import '../data/shopping_repository_impl.dart';
import '../domain/shopping_item.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return SupabaseShoppingRepository(ref.watch(supabaseProvider));
});

final currentShoppingItemsProvider =
    FutureProvider<List<ShoppingItem>>((ref) async {
  final kingdom = await ref.watch(currentKingdomProvider.future);
  if (kingdom == null) return const [];
  return ref.watch(shoppingRepositoryProvider).listItems(kingdom.id);
});

final shoppingRealtimeProvider = Provider.autoDispose<void>((ref) {
  final kingdom = ref.watch(currentKingdomProvider).valueOrNull;
  if (kingdom == null) return;

  final client = ref.watch(supabaseProvider);
  final channel = client
      .channel('shopping-items:${kingdom.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shopping_items',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'kingdom_id',
          value: kingdom.id,
        ),
        callback: (_) => ref.invalidate(currentShoppingItemsProvider),
      )
      .subscribe();

  ref.onDispose(() => client.removeChannel(channel));
});

final shoppingControllerProvider =
    StateNotifierProvider<ShoppingController, AsyncValue<void>>((ref) {
  return ShoppingController(ref);
});

class ShoppingController extends StateNotifier<AsyncValue<void>> {
  ShoppingController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> addItem({
    required String name,
    required String quantity,
    required String category,
    String? note,
  }) async {
    final kingdom = await _ref.read(currentKingdomProvider.future);
    final member = await _ref.read(currentFamilyMemberProvider.future);
    if (kingdom == null || member == null) return false;
    return _run(
      () => _ref.read(shoppingRepositoryProvider).addItem(
            kingdomId: kingdom.id,
            memberId: member.id,
            name: name,
            quantity: quantity,
            category: category,
            note: note,
          ),
    );
  }

  Future<bool> claimItem(String itemId) async {
    final member = await _ref.read(currentFamilyMemberProvider.future);
    if (member == null) return false;
    return _run(
      () => _ref.read(shoppingRepositoryProvider).claimItem(itemId, member.id),
    );
  }

  Future<bool> markPurchased(String itemId) async {
    final member = await _ref.read(currentFamilyMemberProvider.future);
    if (member == null) return false;
    return _run(
      () => _ref
          .read(shoppingRepositoryProvider)
          .markPurchased(itemId, member.id),
    );
  }

  Future<bool> restoreItem(String itemId) {
    return _run(
      () => _ref.read(shoppingRepositoryProvider).restoreItem(itemId),
    );
  }

  Future<bool> archiveItem(String itemId) {
    return _run(
      () => _ref.read(shoppingRepositoryProvider).archiveItem(itemId),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      _ref.invalidate(currentShoppingItemsProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
