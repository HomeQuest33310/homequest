-- HomeQuest Demo World Seed
-- Données globales compatibles avec le schéma actuel.
-- Ne crée pas d'utilisateurs Auth.

insert into skills (id, name, icon, description)
values
  ('organisation', 'Organisation', '🧭', 'Planifier, ranger et structurer les missions du quotidien.'),
  ('cooking', 'Cuisine', '🍳', 'Préparer, nettoyer et aider autour des repas.'),
  ('cleaning', 'Ménage', '🧹', 'Entretenir les espaces de vie du royaume.'),
  ('gardening', 'Jardinage', '🌱', 'Prendre soin des plantes, jardins et extérieurs.'),
  ('teamwork', 'Esprit d’équipe', '🤝', 'Aider les autres aventuriers et coopérer.'),
  ('creativity', 'Créativité', '🎨', 'Imaginer des solutions et embellir le royaume.')
on conflict (id) do update
set
  name = excluded.name,
  icon = excluded.icon,
  description = excluded.description;

insert into content_packs (id, name, language, version, data)
values (
  'homequest-demo-fantasy-fr',
  'Pack Démo Fantasy',
  'fr',
  '0.1.0',
  jsonb_build_object(
    'domains', jsonb_build_array('Manoir', 'Jardin', 'Maison de Mamie'),
    'bosses', jsonb_build_array('Seigneur de la Poussière', 'Dragon des Mauvaises Herbes'),
    'quest_examples', jsonb_build_array(
      'Nettoyer la cuisine',
      'Ranger sa chambre',
      'Arroser les plantes',
      'Sortir les poubelles',
      'Mettre la table'
    )
  )
)
on conflict (id) do update
set
  name = excluded.name,
  language = excluded.language,
  version = excluded.version,
  data = excluded.data;