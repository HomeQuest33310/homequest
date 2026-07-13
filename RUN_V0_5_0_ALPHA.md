# HomeQuest v0.5.0-alpha — Missions et validations

## 1. Appliquer la migration Supabase

Dans Supabase, ouvrir **SQL Editor**, puis exécuter le contenu de :

```text
supabase/migrations/0014_quest_completion_workflow.sql
supabase/migrations/0015_guardian_self_approval.sql
supabase/migrations/0016_gameplay_realtime.sql
supabase/migrations/0017_available_quests_and_guardian_notifications.sql
supabase/migrations/0018_revoke_anonymous_privileged_rpcs.sql
supabase/migrations/0019_quest_assignment_visibility.sql
```

Le résultat attendu est :

```text
Success. No rows returned
```

## 2. Mettre à jour Flutter

Depuis le dossier `app` :

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run -d chrome
```

## 3. Tester la boucle

1. Un Gardien crée et assigne une quête.
2. Le membre ouvre **Mes missions** puis choisit **Mission accomplie**.
3. Un autre Gardien ouvre **Conseil des validations**.
4. Il approuve ou demande de reprendre la mission.
5. Après approbation, vérifier l'XP, l'or, les dégâts au boss et la chronique.
6. Garder deux sessions ouvertes et vérifier qu'une nouvelle assignation apparaît
   automatiquement dans **Mes missions** sans recharger la page.
7. Envoyer une mission : elle disparaît des quêtes disponibles pendant sa
   validation. Une mission quotidienne ou hebdomadaire reviendra à sa prochaine
   période après validation.
8. Avec un autre membre, prendre une quête déjà assignée. Le Gardien doit voir
   un badge dans **Notifications du royaume** sans recharger la page.
9. Vérifier qu'une nouvelle quête affiche **Recrutement · Mission libre**, puis
   que le nom du membre apparaît immédiatement après son auto-assignation.

Un Gardien peut approuver sa propre mission. Cette règle permet aux familles
qui ne possèdent qu'un seul Gardien de faire progresser également ce membre.
La récompense ne peut être attribuée qu'une seule fois.
