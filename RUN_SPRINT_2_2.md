# Sprint 2.2 — Registre des Quêtes

## Installation

1. Dézipper ce livrable à la racine du dépôt `homequest`.
2. Accepter les remplacements.
3. Dans Supabase SQL Editor, exécuter :

```text
supabase/migrations/0007_quests_rpc.sql
```

4. Relancer l’application :

```powershell
cd app
flutter clean
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="https://TON_PROJET.supabase.co" --dart-define=SUPABASE_ANON_KEY="TA_CLE"
```

## Ajouts

- Module Quests
- Modèle `Quest`
- Repository Supabase
- Provider Riverpod
- Dialogue de création de quête
- Liste des quêtes sur le dashboard
- RPC `create_quest()`
- ADR-010

## Test attendu

Depuis le tableau de bord :

1. Cliquer sur **Créer une quête**.
2. Remplir le titre et la tâche réelle.
3. Choisir un Domaine.
4. Valider.
5. La quête apparaît dans le tableau de bord.
6. Une nouvelle entrée apparaît dans les Chroniques.
