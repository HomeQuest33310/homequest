# HomeQuest v0.3.0-alpha

## Installation

1. Dézippez cette archive à la racine du dépôt `homequest`.
2. Acceptez les remplacements.
3. Depuis `app/`, relancez :

```powershell
flutter clean
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="https://TON_PROJET.supabase.co" --dart-define=SUPABASE_ANON_KEY="TA_CLE"
```

## Notes

Aucune nouvelle migration Supabase n'est nécessaire si `0007_quests_rpc.sql` a déjà été exécutée.

Cette version corrige le bug de largeur infinie sur le bouton `Créer une quête` du dashboard.
