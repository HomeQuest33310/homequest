-- HomeQuest MVP schema
-- Migration 0005 - Chronicles and domain policies

create type chronicle_type as enum (
  'kingdom_created',
  'domain_created',
  'quest_completed',
  'boss_defeated',
  'level_up',
  'reward_claimed',
  'mercenary_joined'
);

create table chronicles (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  type chronicle_type not null,
  title text not null,
  body text,
  created_at timestamptz default now()
);

create index idx_chronicles_family_created_at
on chronicles(family_id, created_at desc);

alter table domains enable row level security;
alter table chronicles enable row level security;

create policy "Members can read domains"
on domains for select
to authenticated
using (is_family_member(family_id));

create policy "Guardians can manage domains"
on domains for all
to authenticated
using (is_family_guardian(family_id))
with check (is_family_guardian(family_id));

create policy "Members can read chronicles"
on chronicles for select
to authenticated
using (is_family_member(family_id));

create policy "Guardians can create chronicles"
on chronicles for insert
to authenticated
with check (is_family_guardian(family_id));
