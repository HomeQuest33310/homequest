# ADR-006 — Introduction des Domaines

**Statut :** Acceptée

**Date :** 2026-07-07

---

## Contexte

HomeQuest est conçu comme un jeu de rôle coopératif familial.

Au départ, le concept de "Location" (lieu) semblait suffisant pour représenter les différentes maisons d'une famille.

Cependant, le projet a évolué vers une vision plus immersive :

- une famille peut posséder plusieurs lieux de vie ;
- ces lieux peuvent évoluer avec le jeu ;
- différents univers (médiéval, pirate, espace, etc.) devront pouvoir réutiliser exactement le même moteur de jeu.

Le terme "Location" est trop restrictif.

---

## Décision

Le concept de **Domain** devient une entité de premier niveau du modèle.

Une famille possède un ou plusieurs **Domains**.

Exemples :

- 🏠 Maison principale
- 👵 Maison des grands-parents
- 🏖 Maison de vacances
- 🏕 Camp d'été
- 🚀 Station spatiale (pack Espace)
- 🏴‍☠️ Île du Capitaine (pack Pirates)

Les quêtes sont toujours rattachées à un Domain.

---

## Structure

Chaque Domain contient notamment :

- id
- family_id
- name
- domain_kind
- icon
- description
- is_primary
- created_at

Chaque quête référence :

- domain_id

---

## Pourquoi ce choix ?

Cette architecture permet :

- plusieurs lieux de vie par famille ;
- un système de thèmes sans modifier le modèle de données ;
- des cartes du royaume composées de plusieurs Domaines ;
- des évolutions visuelles indépendantes ;
- l'arrivée future de packs de contenu.

Le moteur du jeu reste identique quel que soit l'univers.

---

## Conséquences

Le MVP supportera dès le départ :

- plusieurs Domaines ;
- un Domaine principal ;
- les quêtes liées à un Domaine.

Les fonctionnalités suivantes sont prévues pour les versions futures :

- carte du royaume ;
- évolution graphique des Domaines ;
- bâtiments ;
- événements propres à un Domaine ;
- déplacements entre Domaines.

---

## Vision long terme

La hiérarchie principale de HomeQuest devient :

Univers
└── Royaume (Famille)
    └── Domaine
        ├── Quêtes
        ├── Aventuriers
        ├── Boss
        └── Récompenses

Cette architecture permet au projet de rester extensible tout en gardant un modèle de données simple.