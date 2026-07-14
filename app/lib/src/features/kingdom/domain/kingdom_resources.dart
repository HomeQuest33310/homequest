class KingdomResources {
  const KingdomResources({
    required this.wood,
    required this.stone,
    required this.provisions,
    required this.crystals,
  });

  factory KingdomResources.fromMap(Map<String, dynamic> map) {
    return KingdomResources(
      wood: (map['wood'] as num?)?.toInt() ?? 0,
      stone: (map['stone'] as num?)?.toInt() ?? 0,
      provisions: (map['provisions'] as num?)?.toInt() ?? 0,
      crystals: (map['crystals'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = KingdomResources(
    wood: 0,
    stone: 0,
    provisions: 0,
    crystals: 0,
  );

  final int wood;
  final int stone;
  final int provisions;
  final int crystals;

  int get total => wood + stone + provisions + crystals;
}
