# HomeQuest — Sprint 2.0

## Objectif

Remplacer la création du Royaume côté Flutter par une fonction RPC Supabase atomique.

Cela corrige les erreurs RLS `403 Forbidden` pendant la création du premier Royaume.

## Installation

Dézippez cette archive à la racine du dépôt `homequest` et acceptez les remplacements.

## Base de données

Dans Supabase SQL Editor, ouvrez et exécutez ce fichier :

```text
supabase/migrations/0006_create_kingdom_rpc.sql
```

Il crée :

- `create_profile_if_needed()` ;
- `create_kingdom(...)`.

## Lancer

Depuis `app/` :

```powershell
flutter clean
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="https://TON_PROJET.supabase.co" --dart-define=SUPABASE_ANON_KEY="TA_CLE"
```

## Test attendu

1. Créer un aventurier ou se connecter.
2. Cliquer sur Créer mon Royaume.
3. Le Royaume, le Domaine principal et la première Chronique doivent être créés.
4. Le tableau de bord doit s'afficher.

## Notes

Si un Royaume existe déjà pour l'utilisateur, HomeQuest ouvre directement le tableau de bord.
