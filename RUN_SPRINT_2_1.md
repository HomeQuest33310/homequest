# Sprint 2.1 — Tableau de bord vivant

## Objectif

Transformer la page d'accueil en véritable tableau de bord HomeQuest :

- en-tête du Royaume ;
- statistiques simples ;
- Domaines ;
- Chroniques récentes ;
- prochaine étape de jeu.

## Installation

Dézippez ce livrable à la racine du dépôt `homequest` et acceptez les remplacements.

Aucune nouvelle migration Supabase n'est nécessaire si les migrations 0001 à 0006 sont déjà appliquées.

## Lancement

Depuis `app/` :

```powershell
flutter clean
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="https://TON_PROJET.supabase.co" --dart-define=SUPABASE_ANON_KEY="TA_CLE"
```

## Résultat attendu

Après connexion, vous devez voir :

- le nom du Royaume ;
- la guilde familiale ;
- le nombre d'aventuriers ;
- le nombre de Domaines ;
- les Chroniques ;
- le Domaine principal.

## Commit conseillé

```powershell
git add .
git commit -m "feat(dashboard): add living kingdom dashboard"
git push
```
