import '../domain/shopping_item.dart';

abstract class ShoppingRepository {
  Future<List<ShoppingItem>> listItems(String kingdomId);

  Future<void> addItem({
    required String kingdomId,
    required String memberId,
    required String name,
    required String quantity,
    required String category,
    String? note,
  });

  Future<void> claimItem(String itemId, String memberId);
  Future<void> markPurchased(String itemId, String memberId);
  Future<void> restoreItem(String itemId);
  Future<void> archiveItem(String itemId);
}
