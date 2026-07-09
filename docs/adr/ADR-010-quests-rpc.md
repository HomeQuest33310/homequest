# ADR-010 — Création des quêtes par RPC

**Statut :** Acceptée

**Date :** 2026-07-07

## Contexte

HomeQuest utilise Row Level Security dans Supabase. Les opérations simples peuvent être faites directement depuis Flutter, mais les opérations métier importantes doivent rester atomiques et sécurisées.

La création d’une quête implique plusieurs éléments : famille, domaine, récompenses, statut et chronique.

## Décision

La création d’une quête passe par la fonction RPC PostgreSQL `create_quest()`.

Flutter n’insère pas directement une quête avec plusieurs opérations séparées. Il appelle une seule fonction métier.

## Conséquences

Cette approche permet :

- de vérifier côté base que l’utilisateur est Gardien ;
- de rattacher la quête à un Domaine valide ;
- de créer une chronique automatiquement ;
- d’éviter les états intermédiaires incohérents ;
- de préparer les futures mécaniques XP, or, compétences et boss.

## MVP

Sprint 2.2 permet :

- de créer une quête ;
- de choisir un Domaine ;
- de définir XP, or et dégâts boss ;
- d’afficher les quêtes du Royaume.

## Hors périmètre

Ne sont pas encore inclus :

- validation des quêtes ;
- attribution à un aventurier ;
- récompenses réelles ;
- application des compétences ;
- dégâts réels au boss.
