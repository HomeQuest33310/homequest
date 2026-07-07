# ADR-006 — Introduction des Domaines

**Statut :** Acceptée

**Date :** 2026-07-07

## Contexte

HomeQuest est conçu comme un jeu de rôle coopératif familial.

Au départ, le concept de "Location" semblait suffisant pour représenter les différentes maisons d'une famille. Le projet évolue cependant vers une vision plus immersive : plusieurs lieux de vie, plusieurs thèmes et des packs de contenu réutilisables.

## Décision

Le concept de **Domain** devient une entité de premier niveau du modèle.

Une famille possède un ou plusieurs **Domains**.

Exemples :

- Maison principale
- Maison des grands-parents
- Maison de vacances
- Camp d'été
- Station spatiale dans un pack Espace
- Île du Capitaine dans un pack Pirates

Les quêtes sont rattachées à un Domain.

## Conséquences

Le MVP supporte dès le départ :

- plusieurs Domaines ;
- un Domaine principal ;
- les quêtes liées à un Domaine.

Les cartes, bâtiments, événements propres à un Domaine et déplacements entre Domaines sont reportés à une version future.
