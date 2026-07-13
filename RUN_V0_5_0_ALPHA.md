# HomeQuest v0.5.0-alpha — Missions et validations

## 1. Appliquer la migration Supabase

Dans Supabase, ouvrir **SQL Editor**, puis exécuter le contenu de :

```text
supabase/migrations/0014_quest_completion_workflow.sql
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

Un Gardien ne peut pas approuver sa propre mission. Pour tester avec un seul
Gardien, attribuer la mission à un Aventurier ou désactiver la validation sur
la quête concernée.
