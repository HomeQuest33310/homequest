-- HomeQuest skills system

create table skills (
  id text primary key,
  name text not null,
  icon text not null,
  description text,
  created_at timestamptz default now()
);

create table member_skills (
  member_id uuid not null references family_members(id) on delete cascade,
  skill_id text not null references skills(id) on delete cascade,
  xp int not null default 0,
  level int not null default 1,
  updated_at timestamptz default now(),
  primary key (member_id, skill_id)
);

create table quest_skill_rewards (
  quest_id uuid not null references quests(id) on delete cascade,
  skill_id text not null references skills(id) on delete cascade,
  xp_reward int not null default 1,
  primary key (quest_id, skill_id)
);

insert into skills (id, name, icon, description) values
  ('daily_life', 'Vie quotidienne', '🏠', 'Routines et autonomie du quotidien'),
  ('cooking', 'Cuisine', '🍳', 'Repas, table, vaisselle et préparation'),
  ('nature', 'Nature', '🌿', 'Jardin, plantes, compost et extérieur'),
  ('knowledge', 'Savoir', '📚', 'Lecture, devoirs et apprentissage'),
  ('creativity', 'Créativité', '🎨', 'Dessin, bricolage, musique et imagination'),
  ('endurance', 'Endurance', '💪', 'Efforts physiques, sport et mouvement'),
  ('helpfulness', 'Entraide', '❤️', 'Aider les autres membres de la famille'),
  ('organization', 'Organisation', '🧹', 'Ranger, trier, nettoyer et structurer'),
  ('animals', 'Animaux', '🐾', 'Soins aux animaux'),
  ('crafting', 'Bricolage', '🔧', 'Réparer, fabriquer et construire')
on conflict (id) do nothing;

create index idx_member_skills_member_id on member_skills(member_id);
create index idx_quest_skill_rewards_quest_id on quest_skill_rewards(quest_id);
