# Invitations HomeQuest

## Principe

Une invitation cible un Royaume précis. Le Royaume représente un foyer et le
Domaine une pièce, une zone ou une activité de ce foyer.

- Le fondateur de la famille peut nommer un Gardien dans n'importe lequel de
  ses Royaumes.
- Un Gardien invite des Aventuriers et des Mercenaires dans les Royaumes dont
  il a la charge.
- Un Mercenaire peut être limité à un Domaine et à une durée.
- L'acceptation crée l'appartenance au Royaume sans donner accès au Royaume
  principal par défaut.

## URL durable et application mobile

Les liens utilisent la forme suivante :

```text
https://homequest33310.github.io/homequest/?invite=TOKEN
```

Cette URL fonctionne dans la PWA. Lors de la publication Android et iOS, le
même domaine pourra être configuré comme Android App Link et iOS Universal
Link. Un ancien email continuera donc à ouvrir HomeQuest.

## Activer GitHub Pages

Dans le dépôt GitHub :

1. Ouvrir `Settings > Secrets and variables > Actions > Variables`.
2. Ajouter `SUPABASE_URL` avec l'URL du projet Supabase.
3. Ajouter `SUPABASE_PUBLISHABLE_KEY` avec la clé publique `sb_publishable_`.
4. Ouvrir `Settings > Pages` et choisir `GitHub Actions` comme source.
5. Lancer le workflow `Deploy HomeQuest Web`.

Ne jamais enregistrer une clé `sb_secret_` ou `service_role` dans GitHub Pages,
Flutter, une variable publique ou le dépôt.

## Configurer Supabase Auth

Dans `Authentication > URL Configuration` :

- Site URL : `https://homequest33310.github.io/homequest/`
- Redirect URL : `https://homequest33310.github.io/homequest/**`
- Développement : ajouter les URL locales nécessaires avec `/**`.

Un fournisseur SMTP personnalisé est nécessaire pour envoyer des invitations
à des adresses qui ne font pas partie de l'équipe Supabase. L'email sera envoyé
par une Edge Function authentifiée ; la clé secrète restera uniquement côté
serveur.
