-- HomeQuest MVP schema
-- Migration 0004 - Domains

create type domain_kind as enum (
  'home',
  'vacation',
  'grandparent',
  'camp',
  'custom'
);

create table domains (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  name text not null,
  domain_kind domain_kind not null default 'home',
  icon text not null default 'home',
  description text,
  is_primary boolean not null default false,
  created_at timestamptz default now()
);

alter table quests
add column domain_id uuid references domains(id) on delete set null;

create index idx_domains_family_id on domains(family_id);
create index idx_quests_domain_id on quests(domain_id);