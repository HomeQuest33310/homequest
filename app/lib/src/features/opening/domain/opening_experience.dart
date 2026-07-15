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
    eyebrow: 'PROLOGUE II · LE PREMIER ROYAUME',
    title: 'Le Royaume reconnaît ton nom',
    phrases: [
      'Une porte que nul ne voyait vient de reconnaître ton pas.',
      'Au-delà des brumes, un foyer allume ses premières lanternes.',
      'Des voix anciennes murmurent déjà les quêtes à venir.',
      'Qu’importe qui en posa la première pierre…',
      'Désormais, ce Royaume compte sur ta lumière.',
    ],
    startLabel: 'Écouter le Royaume s’éveiller',
    finishLabel: 'Entrer dans mon Royaume',
  );
}
