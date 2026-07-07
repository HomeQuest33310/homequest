# HomeQuest — Sprint 1.3

## Objectif

Corriger la page blanche liée au routeur Riverpod/GoRouter et rendre le parcours d'entrée utilisable :

1. création d'un aventurier ;
2. création automatique du profil ;
3. détection du royaume existant ;
4. création du royaume si nécessaire ;
5. affichage du tableau de bord avec la Chronique.

## Installation

Dézippez cette archive à la racine du dépôt `homequest` et acceptez les remplacements.

## Lancer

Depuis `app/` :

```powershell
flutter clean
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="https://TON_PROJET.supabase.co" --dart-define=SUPABASE_ANON_KEY="TA_CLE"
```

## Important Supabase

Les migrations 0001 à 0005 doivent déjà avoir été exécutées dans Supabase.

Dans Supabase Authentication, pour le développement, désactivez temporairement la confirmation email si vous voulez être connecté immédiatement après l'inscription.

## Changements techniques

- Suppression des redirections asynchrones dans `GoRouter`.
- Ajout d'un `HomeGate` qui décide quoi afficher selon l'état utilisateur/famille.
- Authentification rendue plus robuste.
- Correction du cycle Riverpod qui provoquait :

```text
Cannot use ref functions after the dependency of a provider changed
```

## Test attendu

Au lancement :

- si aucun utilisateur n'est connecté : écran "Chroniques de HomeQuest" ;
- après inscription : écran de création du royaume ;
- après création : tableau de bord du royaume et première chronique.
