enum OpeningKind {
  firstAwakening,
  kingdomArrival,
}

class OpeningExperience {
  const OpeningExperience({
    required this.kind,
    required this.eyebrow,
    required this.title,
    required this.phrases,
    required this.startLabel,
    required this.finishLabel,
  });

  final OpeningKind kind;
  final String eyebrow;
  final String title;
  final List<String> phrases;
  final String startLabel;
  final String finishLabel;

  static const firstAwakening = OpeningExperience(
    kind: OpeningKind.firstAwakening,
    eyebrow: 'PROLOGUE I',
    title: 'Les Chroniques sommeillent',
    phrases: [
      'Avant les Royaumes, il n’y avait qu’un murmure.',
      'Chaque geste oublié dessinait une ombre nouvelle.',
      'Puis, au cœur du foyer, une lumière choisit de répondre.',
      'Les anciennes portes connaissent déjà ton nom…',
      'Il ne reste qu’à l’inscrire dans les Chroniques.',
    ],
    startLabel: 'Éveiller les Chroniques',
    finishLabel: 'Créer mon aventurier',
  );

  static const kingdomArrival = OpeningExperience(
    kind: OpeningKind.kingdomArrival,
    eyebrow: 'UN NOUVEAU SEUIL',
    title: 'Le Royaume retient son souffle',
    phrases: [
      'Une porte que nul ne voyait vient de s’éveiller.',
      'Derrière elle, un Royaume attend ses prochains héros.',
      'Des quêtes sans nom frémissent encore dans la brume.',
      'Un feu ancien reconnaît la marque de ton passage…',
      'Avance. Désormais, cette histoire connaît ton nom.',
    ],
    startLabel: 'Écouter l’appel du Royaume',
    finishLabel: 'Franchir le seuil',
  );
}
