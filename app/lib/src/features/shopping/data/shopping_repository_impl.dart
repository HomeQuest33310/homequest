import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/shopping_item.dart';
import 'shopping_repository.dart';

class SupabaseShoppingRepository implements ShoppingRepository {
  SupabaseShoppingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ShoppingItem>> listItems(String kingdomId) async {
    final data = await _client
        .from('shopping_items')
        .select()
        .eq('kingdom_id', kingdomId)
        .neq('status', 'archived')
        .order('created_at', ascending: false);

    return (data as List)
        .map(
          (row) => ShoppingItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> addItem({
    required String kingdomId,
    required String memberId,
    required String name,
    required String quantity,
    required String category,
    String? note,
  }) async {
    await _client.from('shopping_items').insert({
      'kingdom_id': kingdomId,
      'name': name.trim(),
      'quantity': quantity.trim(),
      'category': category,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'added_by': memberId,
    });
  }

  @override
  Future<void> claimItem(String itemId, String memberId) async {
    await _client.from('shopping_items').update({
      'status': 'claimed',
      'claimed_by': memberId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);
  }

  @override
  Future<void> markPurchased(String itemId, String memberId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('shopping_items').update({
      'status': 'purchased',
      'purchased_by': memberId,
      'purchased_at': now,
      'updated_at': now,
    }).eq('id', itemId);
  }

  @override
  Future<void> restoreItem(String itemId) async {
    await _client.from('shopping_items').update({
      'status': 'needed',
      'claimed_by': null,
      'purchased_by': null,
      'purchased_at': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);
  }

  @override
  Future<void> archiveItem(String itemId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('shopping_items').update({
      'status': 'archived',
      'archived_at': now,
      'updated_at': now,
    }).eq('id', itemId);
  }
}
