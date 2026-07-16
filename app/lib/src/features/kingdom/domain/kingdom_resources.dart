class KingdomResources {
  const KingdomResources({
    required this.wood,
    required this.stone,
    required this.provisions,
    required this.crystals,
    this.bossItems = const [],
  });

  factory KingdomResources.fromMap(Map<String, dynamic> map) {
    return KingdomResources(
      wood: (map['wood'] as num?)?.toInt() ?? 0,
      stone: (map['stone'] as num?)?.toInt() ?? 0,
      provisions: (map['provisions'] as num?)?.toInt() ?? 0,
      crystals: (map['crystals'] as num?)?.toInt() ?? 0,
      bossItems: (map['boss_items'] as List? ?? const [])
          .map(
            (item) => KingdomBossItem.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  static const empty = KingdomResources(
    wood: 0,
    stone: 0,
    provisions: 0,
    crystals: 0,
    bossItems: [],
  );

  final int wood;
  final int stone;
  final int provisions;
  final int crystals;
  final List<KingdomBossItem> bossItems;

  int get total => wood + stone + provisions + crystals;
  int get bossItemCount =>
      bossItems.fold(0, (total, item) => total + item.quantity);
  int get tierThreeBossItemCount => bossItems
      .where((item) => item.tier >= 3)
      .fold(0, (total, item) => total + item.quantity);
}

class KingdomBossItem {
  const KingdomBossItem({
    required this.key,
    required this.name,
    required this.emoji,
    required this.tier,
    required this.quantity,
  });

  factory KingdomBossItem.fromMap(Map<String, dynamic> map) {
    return KingdomBossItem(
      key: map['item_key'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      tier: (map['tier'] as num).toInt(),
      quantity: (map['quantity'] as num).toInt(),
    );
  }

  final String key;
  final String name;
  final String emoji;
  final int tier;
  final int quantity;
}
