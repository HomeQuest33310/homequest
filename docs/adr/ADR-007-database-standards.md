# ADR-007 — Standards de base de données

**Statut :** Acceptée

**Date :** 2026-07-07

## Contexte

HomeQuest va évoluer vers un jeu familial complet avec familles, domaines, quêtes, compétences, récompenses, boss, chroniques et packs de contenu.

Pour éviter une base difficile à maintenir, nous définissons des conventions dès le MVP.

## Décision

Les tables principales doivent progressivement suivre ces standards :

- `id` comme clé primaire UUID ;
- `created_at` pour la date de création ;
- `updated_at` lorsque la donnée peut être modifiée ;
- `created_by` lorsque l’auteur est important ;
- index sur les clés étrangères fréquentes ;
- noms de colonnes cohérents ;
- suppression en cascade uniquement quand les données n’ont plus de sens seules.

## Conventions

- Les tables sont au pluriel : `families`, `domains`, `quests`.
- Les clés étrangères utilisent le suffixe `_id`.
- Les rôles et statuts importants utilisent des enums Postgres.
- Les données de jeu configurables doivent aller dans les packs de contenu quand c’est possible.
- La logique sensible doit être côté base ou Edge Function, pas uniquement dans Flutter.

## Conséquences

Avant d’ajouter de grosses fonctionnalités, nous harmoniserons progressivement les anciennes tables.

Le MVP reste simple, mais la structure reste prête pour :

- mode hors ligne ;
- synchronisation ;
- historique ;
- audit ;
- restauration future ;
- contributions open source.