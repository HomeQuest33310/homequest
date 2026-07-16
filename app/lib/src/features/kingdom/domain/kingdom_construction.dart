import 'kingdom_resources.dart';

class KingdomConstruction {
  const KingdomConstruction({
    required this.key,
    required this.name,
    required this.emoji,
    required this.category,
    required this.tier,
    required this.description,
    required this.bonusDescription,
    required this.woodCost,
    required this.stoneCost,
    required this.provisionsCost,
    required this.crystalsCost,
    required this.bossItemsCost,
    required this.tierThreeItemsCost,
    required this.buildHours,
    required this.maxLevel,
    required this.level,
    required this.targetLevel,
    required this.status,
    this.startedAt,
    this.completesAt,
    this.completedAt,
  });

  factory KingdomConstruction.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String key) {
      final value = map[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    return KingdomConstruction(
      key: map['building_key'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      category: map['category'] as String,
      tier: (map['tier'] as num).toInt(),
      description: map['description'] as String,
      bonusDescription: map['bonus_description'] as String,
      woodCost: (map['wood_cost'] as num?)?.toInt() ?? 0,
      stoneCost: (map['stone_cost'] as num?)?.toInt() ?? 0,
      provisionsCost: (map['provisions_cost'] as num?)?.toInt() ?? 0,
      crystalsCost: (map['crystals_cost'] as num?)?.toInt() ?? 0,
      bossItemsCost: (map['boss_items_cost'] as num?)?.toInt() ?? 0,
      tierThreeItemsCost: (map['tier_three_items_cost'] as num?)?.toInt() ?? 0,
      buildHours: (map['build_hours'] as num).toInt(),
      maxLevel: (map['max_level'] as num).toInt(),
      level: (map['level'] as num?)?.toInt() ?? 0,
      targetLevel: (map['target_level'] as num?)?.toInt() ?? 1,
      status: map['status'] as String? ?? 'available',
      startedAt: parseDate('started_at'),
      completesAt: parseDate('completes_at'),
      completedAt: parseDate('completed_at'),
    );
  }

  final String key;
  final String name;
  final String emoji;
  final String category;
  final int tier;
  final String description;
  final String bonusDescription;
  final int woodCost;
  final int stoneCost;
  final int provisionsCost;
  final int crystalsCost;
  final int bossItemsCost;
  final int tierThreeItemsCost;
  final int buildHours;
  final int maxLevel;
  final int level;
  final int targetLevel;
  final String status;
  final DateTime? startedAt;
  final DateTime? completesAt;
  final DateTime? completedAt;

  bool get isInProgress => status == 'building' || status == 'upgrading';
  bool get isBuilt => level > 0;
  bool get isMaxLevel => level >= maxLevel;
  bool get canStart => !isInProgress && !isMaxLevel;
  bool get isMarket => key == 'market';

  Duration get remaining {
    final end = completesAt;
    if (end == null) return Duration.zero;
    final value = end.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  double get constructionProgress {
    final start = startedAt;
    final end = completesAt;
    if (start == null || end == null) return 0;
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0, 1).toDouble();
  }

  bool canAfford(KingdomResources resources) {
    return resources.wood >= woodCost &&
        resources.stone >= stoneCost &&
        resources.provisions >= provisionsCost &&
        resources.crystals >= crystalsCost &&
        resources.bossItemCount >= bossItemsCost &&
        resources.tierThreeBossItemCount >= tierThreeItemsCost;
  }

  String get actionLabel {
    if (isInProgress) {
      return status == 'upgrading' ? 'Amélioration en cours' : 'En chantier';
    }
    if (isMaxLevel) return 'Niveau maximal';
    return level == 0 ? 'Construire' : 'Améliorer au niveau ${level + 1}';
  }
}
