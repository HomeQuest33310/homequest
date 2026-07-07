# ADR-008 — Actions métier via RPC Supabase

**Statut :** Acceptée

**Date :** 2026-07-07

## Contexte

La création d'un Royaume nécessite plusieurs écritures : famille, membre gardien, domaine principal et chronique initiale.

Effectuer ces écritures une par une depuis Flutter crée un état intermédiaire fragile : l'utilisateur n'est pas encore membre de la famille au moment où certaines politiques RLS s'appliquent.

## Décision

Les actions métier importantes seront exécutées côté base de données via des fonctions RPC PostgreSQL.

La première fonction est :

```sql
create_kingdom(p_family_name, p_kingdom_name, p_primary_domain_name)
```

Elle crée atomiquement :

- la famille ;
- le premier gardien ;
- le domaine principal ;
- la première chronique.

## Conséquences

Flutter ne connaît plus les détails internes de la création d'un royaume. Il appelle une seule action métier.

Cette approche sera réutilisée pour :

- valider une quête ;
- distribuer XP, or et compétences ;
- infliger des dégâts aux boss ;
- inviter un mercenaire ;
- créer des chroniques.

## Avantages

- logique métier centralisée ;
- transactions atomiques ;
- moins de problèmes RLS ;
- code Flutter plus simple ;
- meilleure sécurité.
