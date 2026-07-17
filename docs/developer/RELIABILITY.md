# Fiabilité de HomeQuest

Ce document décrit les contrôles qui protègent la branche `main` et le
déploiement Web.

## Contrôles Flutter

Depuis le dossier `app/` :

```powershell
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
```

L’analyse doit terminer sans erreur ni avertissement. Les tests couvrent
notamment les fréquences et disponibilités des quêtes, les catalogues, les
récompenses prioritaires, les avatars, les préférences et l’économie du
Royaume.

La couverture de lignes ne doit pas descendre sous **20 %**. Ce premier seuil
protège la base actuelle ; il doit être relevé progressivement lorsque de
nouveaux parcours sont couverts.

## Contrôles Supabase

La base locale est reconstruite depuis les migrations avant d’exécuter les
contrats pgTAP :

```powershell
supabase db start
supabase db reset --local --yes
supabase test db
supabase db lint --local --schema public --level warning --fail-on error
```

La remise à zéro concerne uniquement la base locale. Elle rejoue toutes les
migrations avant les tests afin qu’une ancienne sauvegarde Docker ne masque pas
une migration manquante.

Les 30 contrats vérifient la présence des tables, colonnes et fonctions
critiques, l’activation de RLS et l’absence d’accès anonyme aux fonctions
sensibles. Le lint PostgreSQL bloque également toute fonction contenant une
erreur de typage ou une référence ambiguë.

Le fichier `supabase/seed.sql` doit rester dépourvu de données personnelles ou
de données copiées depuis la production.

## Intégration continue

La pull request et chaque mise à jour de `main` exécutent :

1. l’analyse et les tests Flutter ;
2. la reconstruction et les tests de la base Supabase ;
3. la compilation Web, uniquement après la réussite des deux contrôles ;
4. le déploiement GitHub Pages, uniquement après une compilation réussie.

Une pull request en échec ne doit pas être fusionnée. La protection de branche
GitHub doit rendre obligatoires les contrôles **Flutter quality** et
**Supabase quality**.

## Dépendances

Le fichier `app/pubspec.lock` est versionné afin que les développeurs et
l’intégration continue utilisent les mêmes versions résolues. Les mises à jour
de dépendances doivent être isolées dans une pull request et accompagnées de la
suite complète de contrôles.
