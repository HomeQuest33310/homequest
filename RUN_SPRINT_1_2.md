# HomeQuest — Sprint 1.2

## Objectif

Ce livrable ajoute la première version des **Chroniques du Royaume** et stabilise le parcours :

1. inscription / connexion ;
2. création du Royaume ;
3. création du Domaine principal ;
4. création de la première Chronique ;
5. affichage du tableau de bord immersif.

## Installation

Dézippez cette archive à la racine du dépôt `homequest` et acceptez les remplacements.

## Base de données

Si vos migrations ne sont pas encore appliquées dans Supabase, appliquez-les dans cet ordre via Supabase SQL Editor :

1. `0001_initial_schema.sql`
2. `0002_skills.sql`
3. `0003_rls_policies.sql`
4. `0004_domains.sql`
5. `0005_chronicles_and_domain_policies.sql`

Important : ce livrable remplace `0003_rls_policies.sql` par une version corrigée, car l'ancienne version référençait des tables qui n'existaient pas encore.

## Lancement

Depuis `app/` :

```powershell
flutter clean
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="https://TON_PROJET.supabase.co" --dart-define=SUPABASE_ANON_KEY="TA_CLE"
```

## Commit conseillé

```powershell
git add .
git commit -m "feat(chronicles): add kingdom chronicles to dashboard"
git push
```
