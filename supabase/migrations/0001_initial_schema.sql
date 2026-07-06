-- HomeQuest MVP schema
create extension if not exists pgcrypto;

create type family_role as enum ('guardian', 'adventurer', 'child', 'mercenary');
create type quest_status as enum ('active', 'paused', 'archived');
create type quest_frequency as enum ('once', 'daily', 'weekly');
create type completion_status as enum ('pending', 'approved', 'rejected');
create type boss_status as enum ('active', 'defeated', 'expired');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_key text,
  created_at timestamptz default now()
);

create table families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kingdom_name text not null,
  owner_id uuid not null references profiles(id),
  created_at timestamptz default now()
);

create table family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role family_role not null default 'adventurer',
  level int not null default 1,
  xp int not null default 0,
  gold int not null default 0,
  joined_at timestamptz default now(),
  expires_at timestamptz,
  unique(family_id, user_id)
);

create table quests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  created_by uuid not null references profiles(id),
  title text not null,
  real_task text not null,
  description text,
  region_key text,
  xp_reward int not null default 10,
  gold_reward int not null default 5,
  boss_damage int not null default 5,
  frequency quest_frequency not null default 'once',
  requires_approval boolean not null default true,
  status quest_status not null default 'active',
  created_at timestamptz default now()
);

create table quest_assignments (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references quests(id) on delete cascade,
  member_id uuid not null references family_members(id) on delete cascade,
  assigned_at timestamptz default now(),
  unique(quest_id, member_id)
);

create table quest_completions (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references quests(id) on delete cascade,
  completed_by uuid not null references family_members(id),
  status completion_status not null default 'pending',
  photo_url text,
  note text,
  completed_at timestamptz default now(),
  approved_by uuid references family_members(id),
  approved_at timestamptz
);

create table bosses (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  name text not null,
  max_hp int not null,
  current_hp int not null,
  status boss_status not null default 'active',
  starts_at timestamptz default now(),
  ends_at timestamptz,
  created_at timestamptz default now()
);

create table content_packs (
  id text primary key,
  name text not null,
  language text not null,
  version text not null,
  data jsonb not null,
  created_at timestamptz default now()
);
