import 'package:flutter/services.dart';

class QuestSuggestion {
  const QuestSuggestion({
    required this.id,
    required this.locationKey,
    required this.locationLabel,
    required this.realTask,
    required this.heroicTitle,
    required this.emoji,
    required this.element,
    required this.skills,
    required this.xpReward,
    required this.difficulty,
  });

  final int id;
  final String locationKey;
  final String locationLabel;
  final String realTask;
  final String heroicTitle;
  final String emoji;
  final String element;
  final List<HeroicSkill> skills;
  final int xpReward;
  final int difficulty;

  int get goldReward => difficulty * 5;
  int get bossDamage => difficulty * 5;
}

class HeroicSkill {
  const HeroicSkill({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });

  final String id;
  final String name;
  final String icon;
  final String description;
}

const questLocationLabels = <String, String>{
  'custom': 'Autre lieu',
  'kitchen': 'Cuisine',
  'bedroom': 'Chambre',
  'bathroom': 'Salle de bain',
  'living_room': 'Salon',
  'outdoor': 'Extérieur',
  'laundry': 'Lessive',
  'special_cooking': 'Cuisine spéciale',
  'quick_daily': 'Quotidien rapide',
  'family_group': 'Toute la maison',
  'animal_care': 'Soin des animaux',
  'home_routine': 'Maison et routines',
  'vehicle': 'Véhicules et transport',
  'wellbeing': 'Santé et bien-être',
  'community': 'Liens et communauté',
};

const heroicSkills = <HeroicSkill>[
  HeroicSkill(
    id: 'strength',
    name: 'Puissance du Titan',
    icon: '💪',
    description: 'Force physique et travaux exigeants.',
  ),
  HeroicSkill(
    id: 'agility',
    name: 'Pas du Zéphyr',
    icon: '🏃',
    description: 'Rapidité, précision et mouvement.',
  ),
  HeroicSkill(
    id: 'intelligence',
    name: 'Sagesse des Arcanes',
    icon: '🧠',
    description: 'Réflexion, organisation et stratégie.',
  ),
  HeroicSkill(
    id: 'leadership',
    name: 'Commandement du Royaume',
    icon: '👑',
    description: 'Initiative, courage et responsabilité.',
  ),
  HeroicSkill(
    id: 'endurance',
    name: 'Souffle du Colosse',
    icon: '⏳',
    description: 'Persévérance et résistance dans la durée.',
  ),
  HeroicSkill(
    id: 'dexterity',
    name: 'Main de l’Artificier',
    icon: '✋',
    description: 'Habileté manuelle et coordination.',
  ),
  HeroicSkill(
    id: 'cleaning',
    name: 'Purification Sacrée',
    icon: '✨',
    description: 'Hygiène, propreté et restauration des lieux.',
  ),
  HeroicSkill(
    id: 'organization',
    name: 'Ordre du Royaume',
    icon: '📦',
    description: 'Rangement, classement et structure.',
  ),
  HeroicSkill(
    id: 'cooking',
    name: 'Alchimie des Saveurs',
    icon: '🍳',
    description: 'Préparation, créativité et goût.',
  ),
  HeroicSkill(
    id: 'gardening',
    name: 'Communion Sylvestre',
    icon: '🌱',
    description: 'Culture, entretien et croissance du vivant.',
  ),
];

class QuestSuggestionCatalog {
  static Future<List<QuestSuggestion>> load() async {
    final source = await rootBundle.loadString(
      'assets/content/quest_suggestions.md',
    );
    final suggestions = <QuestSuggestion>[];
    var location = const _Location('', '');

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      final detectedLocation = _locationFromHeading(line);
      if (detectedLocation != null) {
        location = detectedLocation;
        continue;
      }
      if (location.key.isEmpty || !RegExp(r'^\|\s*\d+\s*\|').hasMatch(line)) {
        continue;
      }

      final rawColumns = line.split('|');
      if (rawColumns.length < 10) continue;
      final columns = rawColumns
          .sublist(1, rawColumns.length - 1)
          .map((column) => column.trim())
          .toList();
      if (columns.length < 8) continue;

      final id = int.tryParse(columns[0]);
      final xp = int.tryParse(columns[6]);
      if (id == null || xp == null) continue;

      final skills = columns[5]
          .split(',')
          .map(_skillFromDocumentLabel)
          .whereType<HeroicSkill>()
          .toList();
      if (skills.length != 2) continue;

      suggestions.add(
        QuestSuggestion(
          id: id,
          locationKey: location.key,
          locationLabel: location.label,
          realTask: columns[1],
          heroicTitle: columns[2],
          emoji: columns[3],
          element: columns[4],
          skills: skills,
          xpReward: xp,
          difficulty: '⭐'.allMatches(columns[7]).length.clamp(1, 5).toInt(),
        ),
      );
    }

    return suggestions;
  }
}

class _Location {
  const _Location(this.key, this.label);

  final String key;
  final String label;
}

_Location? _locationFromHeading(String heading) {
  if (!heading.startsWith('## ')) return null;
  if (heading.contains('SOIN DES ANIMAUX')) {
    return const _Location('animal_care', 'Soin des animaux');
  }
  if (heading.contains('MAISON ET DES ROUTINES')) {
    return const _Location('home_routine', 'Maison et routines');
  }
  if (heading.contains('VÉHICULES ET DU TRANSPORT')) {
    return const _Location('vehicle', 'Véhicules et transport');
  }
  if (heading.contains('SANTÉ ET DE BIEN-ÊTRE')) {
    return const _Location('wellbeing', 'Santé et bien-être');
  }
  if (heading.contains('LIENS ET DE LA COMMUNAUTÉ')) {
    return const _Location('community', 'Liens et communauté');
  }
  if (heading.contains('CULINAIRES SPÉCIALES')) {
    return const _Location('special_cooking', 'Cuisine spéciale');
  }
  if (heading.contains('QUOTIDIENNES RAPIDES')) {
    return const _Location('quick_daily', 'Quotidien rapide');
  }
  if (heading.contains('GROUPE (FAMILLE)')) {
    return const _Location('family_group', 'Toute la maison');
  }
  if (heading.contains('SALLE DE BAIN')) {
    return const _Location('bathroom', 'Salle de bain');
  }
  if (heading.contains('CHAMBRES')) {
    return const _Location('bedroom', 'Chambre');
  }
  if (heading.contains('SALON')) {
    return const _Location('living_room', 'Salon');
  }
  if (heading.contains('EXTÉRIEURES')) {
    return const _Location('outdoor', 'Extérieur');
  }
  if (heading.contains('LESSIVE')) {
    return const _Location('laundry', 'Lessive');
  }
  if (heading.contains('CUISINE')) {
    return const _Location('kitchen', 'Cuisine');
  }
  return null;
}

HeroicSkill? _skillFromDocumentLabel(String label) {
  final normalized = label.toLowerCase();
  const sourceNames = <String, String>{
    'force': 'strength',
    'agilité': 'agility',
    'intelligence': 'intelligence',
    'leadership': 'leadership',
    'endurance': 'endurance',
    'dextérité': 'dexterity',
    'nettoyage': 'cleaning',
    'rangement': 'organization',
    'cuisine': 'cooking',
    'jardinage': 'gardening',
  };
  for (final entry in sourceNames.entries) {
    if (normalized.contains(entry.key)) {
      return heroicSkills.firstWhere((skill) => skill.id == entry.value);
    }
  }
  return null;
}

List<int> skillPointsForDifficulty(int difficulty) {
  switch (difficulty) {
    case 1:
      return const [8, 5];
    case 2:
      return const [15, 10];
    case 3:
      return const [25, 15];
    case 4:
      return const [35, 25];
    default:
      return const [50, 35];
  }
}
