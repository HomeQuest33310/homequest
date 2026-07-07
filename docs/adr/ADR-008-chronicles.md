# ADR-008 — Chroniques du Royaume

**Statut :** Acceptée

**Date :** 2026-07-07

## Contexte

HomeQuest ne doit pas être une simple liste de tâches. Le projet doit raconter l'histoire de la famille sous forme de jeu coopératif.

## Décision

Nous introduisons les **Chroniques du Royaume** dès le MVP.

Une chronique est un souvenir narratif lié à une famille : création du royaume, création d'un domaine, quête accomplie, boss vaincu, arrivée d'un mercenaire, etc.

## Pourquoi

Les chroniques donnent une identité émotionnelle au projet. Elles transforment les actions du quotidien en souvenirs familiaux.

## MVP

Le MVP stocke les chroniques dans la table `chronicles` et affiche les plus récentes sur le tableau de bord.

La première chronique est créée automatiquement lorsque le royaume est fondé.

## Futures évolutions

- Livre des souvenirs par mois et par année.
- Filtres par domaine et par aventurier.
- Chroniques illustrées.
- Export familial.
- Chroniques générées par packs de contenu.
