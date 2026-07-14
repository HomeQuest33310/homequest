-- Route legacy creation RPCs to the primary kingdom automatically.

create or replace function public.ensure_family_primary_kingdom()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.kingdoms (
    family_id, name, kind, icon, description, is_primary, created_by, created_at
  ) values (
    new.id,
    new.kingdom_name,
    'home',
    '🏠',
    'Le foyer fondateur de la famille.',
    true,
    new.owner_id,
    coalesce(new.created_at, now())
  )
  on conflict do nothing;
  return new;
end;
$$;

create or replace function public.route_member_to_primary_kingdom()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  primary_kingdom_id uuid;
begin
  select kingdom.id into primary_kingdom_id
  from public.kingdoms kingdom
  where kingdom.family_id = new.family_id
    and kingdom.is_primary
    and kingdom.archived_at is null
  limit 1;

  if primary_kingdom_id is not null then
    insert into public.kingdom_members (
      kingdom_id, member_id, role, is_active, expires_at, joined_at
    ) values (
      primary_kingdom_id,
      new.id,
      case
        when new.role = 'child' then 'adventurer'::public.family_role
        else new.role
      end,
      new.is_active,
      new.expires_at,
      coalesce(new.joined_at, now())
    )
    on conflict (kingdom_id, member_id) do update set
      role = excluded.role,
      is_active = excluded.is_active,
      expires_at = excluded.expires_at;
  end if;
  return new;
end;
$$;

create or replace function public.route_domain_to_kingdom()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.kingdom_id is null then
    select kingdom.id into new.kingdom_id
    from public.kingdoms kingdom
    where kingdom.family_id = new.family_id
      and kingdom.is_primary
      and kingdom.archived_at is null
    limit 1;
  end if;
  return new;
end;
$$;

create or replace function public.route_quest_to_kingdom()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.kingdom_id is null and new.domain_id is not null then
    select domain.kingdom_id into new.kingdom_id
    from public.domains domain
    where domain.id = new.domain_id;
  end if;

  if new.kingdom_id is null then
    select kingdom.id into new.kingdom_id
    from public.kingdoms kingdom
    where kingdom.family_id = new.family_id
      and kingdom.is_primary
      and kingdom.archived_at is null
    limit 1;
  end if;
  return new;
end;
$$;

create or replace function public.route_boss_to_kingdom()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.kingdom_id is null then
    select kingdom.id into new.kingdom_id
    from public.kingdoms kingdom
    where kingdom.family_id = new.family_id
      and kingdom.is_primary
      and kingdom.archived_at is null
    limit 1;
  end if;
  return new;
end;
$$;

revoke all on function public.ensure_family_primary_kingdom()
  from public, anon, authenticated;
revoke all on function public.route_member_to_primary_kingdom()
  from public, anon, authenticated;
revoke all on function public.route_domain_to_kingdom()
  from public, anon, authenticated;
revoke all on function public.route_quest_to_kingdom()
  from public, anon, authenticated;
revoke all on function public.route_boss_to_kingdom()
  from public, anon, authenticated;

drop trigger if exists families_create_primary_kingdom on public.families;
create trigger families_create_primary_kingdom
after insert on public.families
for each row execute function public.ensure_family_primary_kingdom();

drop trigger if exists family_members_route_primary_kingdom
  on public.family_members;
create trigger family_members_route_primary_kingdom
after insert or update of role, is_active, expires_at
on public.family_members
for each row execute function public.route_member_to_primary_kingdom();

drop trigger if exists domains_route_kingdom on public.domains;
create trigger domains_route_kingdom
before insert or update of family_id, kingdom_id
on public.domains
for each row execute function public.route_domain_to_kingdom();

drop trigger if exists quests_route_kingdom on public.quests;
create trigger quests_route_kingdom
before insert or update of family_id, domain_id, kingdom_id
on public.quests
for each row execute function public.route_quest_to_kingdom();

drop trigger if exists bosses_route_kingdom on public.bosses;
create trigger bosses_route_kingdom
before insert or update of family_id, kingdom_id
on public.bosses
for each row execute function public.route_boss_to_kingdom();

-- Final consistency pass before enforcing the new hierarchy.
update public.domains domain
set kingdom_id = kingdom.id
from public.kingdoms kingdom
where domain.kingdom_id is null
  and kingdom.family_id = domain.family_id
  and kingdom.is_primary
  and kingdom.archived_at is null;

update public.quests quest
set kingdom_id = domain.kingdom_id
from public.domains domain
where quest.kingdom_id is null
  and domain.id = quest.domain_id;

update public.quests quest
set kingdom_id = kingdom.id
from public.kingdoms kingdom
where quest.kingdom_id is null
  and kingdom.family_id = quest.family_id
  and kingdom.is_primary
  and kingdom.archived_at is null;

update public.bosses boss
set kingdom_id = kingdom.id
from public.kingdoms kingdom
where boss.kingdom_id is null
  and kingdom.family_id = boss.family_id
  and kingdom.is_primary
  and kingdom.archived_at is null;

alter table public.domains alter column kingdom_id set not null;
alter table public.quests alter column kingdom_id set not null;
alter table public.bosses alter column kingdom_id set not null;

notify pgrst, 'reload schema';
