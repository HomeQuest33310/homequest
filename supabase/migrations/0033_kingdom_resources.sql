-- Collective kingdom resources earned from approved quests.

create table if not exists public.kingdom_resources (
  family_id uuid primary key references public.families(id) on delete cascade,
  wood integer not null default 0 check (wood >= 0),
  stone integer not null default 0 check (stone >= 0),
  provisions integer not null default 0 check (provisions >= 0),
  crystals integer not null default 0 check (crystals >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.kingdom_resource_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  completion_id uuid not null unique
    references public.quest_completions(id) on delete cascade,
  quest_element text not null,
  quest_difficulty integer not null check (quest_difficulty between 1 and 5),
  wood integer not null default 0 check (wood >= 0),
  stone integer not null default 0 check (stone >= 0),
  provisions integer not null default 0 check (provisions >= 0),
  crystals integer not null default 0 check (crystals >= 0),
  created_at timestamptz not null default now()
);

create index if not exists kingdom_resource_events_family_created_idx
  on public.kingdom_resource_events(family_id, created_at desc);

alter table public.kingdom_resources enable row level security;
alter table public.kingdom_resource_events enable row level security;

grant select on public.kingdom_resources to authenticated;
grant select on public.kingdom_resource_events to authenticated;

drop policy if exists "Kingdom members can read resources"
  on public.kingdom_resources;
create policy "Kingdom members can read resources"
on public.kingdom_resources
for select
to authenticated
using ((select public.is_family_member(family_id)));

drop policy if exists "Kingdom members can read resource events"
  on public.kingdom_resource_events;
create policy "Kingdom members can read resource events"
on public.kingdom_resource_events
for select
to authenticated
using ((select public.is_family_member(family_id)));

create or replace function public.award_kingdom_resources()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_quest public.quests;
  normalized_element text;
  quest_level integer;
  wood_gain integer := 0;
  stone_gain integer := 0;
  provisions_gain integer := 0;
  crystal_gain integer := 0;
  event_id uuid;
begin
  if new.status <> 'approved'
     or old.status = 'approved' then
    return new;
  end if;

  select * into target_quest
  from public.quests
  where id = new.quest_id;

  if target_quest.id is null then
    return new;
  end if;

  normalized_element := lower(coalesce(target_quest.element, 'neutre'));
  quest_level := greatest(1, least(5, coalesce(target_quest.difficulty, 1)));

  if normalized_element like '%terre%' then
    wood_gain := quest_level;
    stone_gain := quest_level * 2;
  elsif normalized_element like '%feu%' then
    stone_gain := quest_level * 2;
    crystal_gain := quest_level;
  elsif normalized_element like '%eau%'
     or normalized_element like '%glace%' then
    provisions_gain := quest_level * 2;
    crystal_gain := quest_level;
  elsif normalized_element like '%air%' then
    wood_gain := quest_level;
    provisions_gain := quest_level * 2;
  elsif normalized_element like '%métal%'
     or normalized_element like '%metal%' then
    stone_gain := quest_level * 3;
  elsif normalized_element like '%électric%'
     or normalized_element like '%electric%' then
    stone_gain := quest_level;
    crystal_gain := quest_level * 2;
  elsif normalized_element like '%magie%'
     or normalized_element like '%arcane%' then
    crystal_gain := quest_level * 2;
  elsif normalized_element like '%nature%' then
    wood_gain := quest_level * 2;
    provisions_gain := quest_level;
  else
    wood_gain := quest_level;
    stone_gain := quest_level;
    provisions_gain := quest_level;
  end if;

  insert into public.kingdom_resource_events (
    family_id,
    completion_id,
    quest_element,
    quest_difficulty,
    wood,
    stone,
    provisions,
    crystals
  ) values (
    target_quest.family_id,
    new.id,
    target_quest.element,
    quest_level,
    wood_gain,
    stone_gain,
    provisions_gain,
    crystal_gain
  )
  on conflict (completion_id) do nothing
  returning id into event_id;

  if event_id is null then
    return new;
  end if;

  insert into public.kingdom_resources (
    family_id, wood, stone, provisions, crystals, updated_at
  ) values (
    target_quest.family_id,
    wood_gain,
    stone_gain,
    provisions_gain,
    crystal_gain,
    now()
  )
  on conflict (family_id) do update set
    wood = public.kingdom_resources.wood + excluded.wood,
    stone = public.kingdom_resources.stone + excluded.stone,
    provisions = public.kingdom_resources.provisions + excluded.provisions,
    crystals = public.kingdom_resources.crystals + excluded.crystals,
    updated_at = now();

  return new;
end;
$$;

revoke all on function public.award_kingdom_resources()
  from public, anon, authenticated;

drop trigger if exists quest_completion_awards_kingdom_resources
  on public.quest_completions;
create trigger quest_completion_awards_kingdom_resources
after update of status on public.quest_completions
for each row
execute function public.award_kingdom_resources();

-- Give every existing kingdom a resource chest, including empty kingdoms.
insert into public.kingdom_resources (family_id)
select family.id from public.families family
on conflict (family_id) do nothing;

-- Backfill one immutable ledger event for every historical approved quest.
insert into public.kingdom_resource_events (
  family_id,
  completion_id,
  quest_element,
  quest_difficulty,
  wood,
  stone,
  provisions,
  crystals,
  created_at
)
select
  quest.family_id,
  completion.id,
  quest.element,
  greatest(1, least(5, coalesce(quest.difficulty, 1))),
  case
    when lower(quest.element) like '%terre%' then quest.difficulty
    when lower(quest.element) like '%air%' then quest.difficulty
    when lower(quest.element) like '%nature%' then quest.difficulty * 2
    when not (lower(quest.element) like any (
      array['%feu%', '%eau%', '%glace%', '%métal%', '%metal%',
            '%électric%', '%electric%', '%magie%', '%arcane%']
    )) then quest.difficulty
    else 0
  end,
  case
    when lower(quest.element) like '%terre%' then quest.difficulty * 2
    when lower(quest.element) like '%feu%' then quest.difficulty * 2
    when lower(quest.element) like '%métal%'
      or lower(quest.element) like '%metal%' then quest.difficulty * 3
    when lower(quest.element) like '%électric%'
      or lower(quest.element) like '%electric%' then quest.difficulty
    when not (lower(quest.element) like any (
      array['%eau%', '%glace%', '%air%', '%nature%', '%magie%', '%arcane%']
    )) then quest.difficulty
    else 0
  end,
  case
    when lower(quest.element) like '%eau%'
      or lower(quest.element) like '%glace%' then quest.difficulty * 2
    when lower(quest.element) like '%air%' then quest.difficulty * 2
    when lower(quest.element) like '%nature%' then quest.difficulty
    when not (lower(quest.element) like any (
      array['%terre%', '%feu%', '%métal%', '%metal%', '%électric%',
            '%electric%', '%magie%', '%arcane%']
    )) then quest.difficulty
    else 0
  end,
  case
    when lower(quest.element) like '%feu%' then quest.difficulty
    when lower(quest.element) like '%eau%'
      or lower(quest.element) like '%glace%' then quest.difficulty
    when lower(quest.element) like '%électric%'
      or lower(quest.element) like '%electric%' then quest.difficulty * 2
    when lower(quest.element) like '%magie%'
      or lower(quest.element) like '%arcane%' then quest.difficulty * 2
    else 0
  end,
  coalesce(completion.approved_at, completion.completed_at, now())
from public.quest_completions completion
join public.quests quest on quest.id = completion.quest_id
where completion.status = 'approved'
on conflict (completion_id) do nothing;

update public.kingdom_resources resources
set wood = totals.wood,
    stone = totals.stone,
    provisions = totals.provisions,
    crystals = totals.crystals,
    updated_at = now()
from (
  select
    family_id,
    sum(wood)::integer as wood,
    sum(stone)::integer as stone,
    sum(provisions)::integer as provisions,
    sum(crystals)::integer as crystals
  from public.kingdom_resource_events
  group by family_id
) totals
where resources.family_id = totals.family_id;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'kingdom_resources'
  ) then
    alter publication supabase_realtime add table public.kingdom_resources;
  end if;
end;
$$;

notify pgrst, 'reload schema';
