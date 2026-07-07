# HomeQuest Sprint 1.1 — Création du Royaume

## Installation

Copier le contenu de cette archive à la racine du dépôt `homequest` en acceptant les remplacements.

## Lancer l'application

Depuis `app/` :

```powershell
flutter clean
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="https://TON_PROJET.supabase.co" --dart-define=SUPABASE_ANON_KEY="TA_CLE_PUBLIC_ANON"
```

## Fonctionnalités ajoutées

- Page d'authentification simple
- Création du royaume
- Création automatique du domaine principal
- Tableau de bord du royaume
- Liste des domaines
- Chronique statique du royaume

## Base de données

La migration `0004_domains.sql` doit être appliquée dans Supabase après `0001`, `0002` et `0003`.
