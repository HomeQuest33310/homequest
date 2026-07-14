class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.kingdomId,
    required this.name,
    required this.quantity,
    required this.category,
    required this.status,
    required this.addedBy,
    required this.createdAt,
    this.note,
    this.claimedBy,
    this.purchasedBy,
    this.purchasedAt,
  });

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] as String,
      kingdomId: map['kingdom_id'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as String? ?? '1',
      category: map['category'] as String? ?? 'Autre',
      note: map['note'] as String?,
      status: map['status'] as String,
      addedBy: map['added_by'] as String,
      claimedBy: map['claimed_by'] as String?,
      purchasedBy: map['purchased_by'] as String?,
      purchasedAt: map['purchased_at'] == null
          ? null
          : DateTime.parse(map['purchased_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String kingdomId;
  final String name;
  final String quantity;
  final String category;
  final String? note;
  final String status;
  final String addedBy;
  final String? claimedBy;
  final String? purchasedBy;
  final DateTime? purchasedAt;
  final DateTime createdAt;

  bool get isNeeded => status == 'needed';
  bool get isClaimed => status == 'claimed';
  bool get isPurchased => status == 'purchased';
}
