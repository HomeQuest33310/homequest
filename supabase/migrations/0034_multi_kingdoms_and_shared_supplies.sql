-- A family is a guild that may contain several physical kingdoms (homes).
-- Domains are zones, rooms or major activities inside one kingdom.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'kingdom_kind') then
    create type public.kingdom_kind as enum (
      'home', 'vacation', 'grandparent', 'camp', 'custom'
    );
  end if;
  if not exists (select 1 from pg_type where typname = 'shopping_item_status') then
    create type public.shopping_item_status as enum (
      'needed', 'claimed', 'purchased', 'archived'
    );
  end if;
end;
$$;

create table if not exists public.kingdoms (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  kind public.kingdom_kind not null default 'home',
  icon text not null default '🏠',
  description text,
  is_primary boolean not null default false,
  created_by uuid not null references public.profiles(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists kingdoms_one_primary_per_family_idx
  on public.kingdoms(family_id)
  where is_primary and archived_at is null;
create index if not exists kingdoms_family_created_idx
  on public.kingdoms(family_id, created_at);

create table if not exists public.kingdom_members (
  id uuid primary key default gen_random_uuid(),
  kingdom_id uuid not null references public.kingdoms(id) on delete cascade,
  member_id uuid not null references public.family_members(id) on delete cascade,
  role public.family_role not null default 'adventurer'
    check (role in ('guardian', 'adventurer', 'mercenary')),
  is_active boolean not null default true,
  expires_at timestamptz,
  assigned_by uuid references public.family_members(id) on delete set null,
  joined_at timestamptz not null default now(),
  unique (kingdom_id, member_id)
);

create index if not exists kingdom_members_member_idx
  on public.kingdom_members(member_id, is_active);
create index if not exists kingdom_members_kingdom_role_idx
  on public.kingdom_members(kingdom_id, role, is_active);

alter table public.domains
  add column if not exists kingdom_id uuid
    references public.kingdoms(id) on delete cascade,
  add column if not exists zone_kind text not null default 'whole_home',
  add column if not exists archived_at timestamptz;

alter table public.quests
  add column if not exists kingdom_id uuid
    references public.kingdoms(id) on delete cascade;

alter table public.bosses
  add column if not exists kingdom_id uuid
    references public.kingdoms(id) on delete cascade;

create index if not exists domains_kingdom_active_idx
  on public.domains(kingdom_id, created_at)
  where archived_at is null;
create index if not exists quests_kingdom_status_idx
  on public.quests(kingdom_id, status, created_at desc);
create index if not exists bosses_kingdom_status_idx
  on public.bosses(kingdom_id, status, created_at desc);

-- Preserve each existing family as one primary kingdom.
insert into public.kingdoms (
  family_id, name, kind, icon, description, is_primary, created_by, created_at
)
select
  family.id,
  family.kingdom_name,
  'home'::public.kingdom_kind,
  '🏠',
  'Le foyer fondateur de la famille.',
  true,
  family.owner_id,
  coalesce(family.created_at, now())
from public.families family
where not exists (
  select 1 from public.kingdoms kingdom
  where kingdom.family_id = family.id
)
on conflict do nothing;

-- Existing members retain access and their role in the primary kingdom.
insert into public.kingdom_members (
  kingdom_id, member_id, role, is_active, expires_at, joined_at
)
select
  kingdom.id,
  member.id,
  case
    when member.role = 'child' then 'adventurer'::public.family_role
    else member.role
  end,
  member.is_active,
  member.expires_at,
  coalesce(member.joined_at, now())
from public.family_members member
join public.kingdoms kingdom
  on kingdom.family_id = member.family_id
 and kingdom.is_primary
 and kingdom.archived_at is null
on conflict (kingdom_id, member_id) do nothing;

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

create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  kingdom_id uuid not null references public.kingdoms(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  quantity text not null default '1' check (char_length(trim(quantity)) between 1 and 40),
  category text not null default 'Autre',
  note text,
  status public.shopping_item_status not null default 'needed',
  added_by uuid not null references public.family_members(id),
  claimed_by uuid references public.family_members(id),
  purchased_by uuid references public.family_members(id),
  purchased_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shopping_items_kingdom_status_created_idx
  on public.shopping_items(kingdom_id, status, created_at desc);
create index if not exists shopping_items_added_by_idx
  on public.shopping_items(added_by);
create index if not exists shopping_items_claimed_by_idx
  on public.shopping_items(claimed_by)
  where claimed_by is not null;
create index if not exists shopping_items_purchased_by_idx
  on public.shopping_items(purchased_by)
  where purchased_by is not null;

create or replace function public.is_kingdom_member(target_kingdom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.kingdom_members kingdom_member
    join public.family_members family_member
      on family_member.id = kingdom_member.member_id
    where kingdom_member.kingdom_id = target_kingdom_id
      and family_member.user_id = auth.uid()
      and family_member.is_active
      and kingdom_member.is_active
      and (family_member.expires_at is null or family_member.expires_at > now())
      and (kingdom_member.expires_at is null or kingdom_member.expires_at > now())
  );
$$;

create or replace function public.is_kingdom_guardian(target_kingdom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.kingdom_members kingdom_member
    join public.family_members family_member
      on family_member.id = kingdom_member.member_id
    where kingdom_member.kingdom_id = target_kingdom_id
      and family_member.user_id = auth.uid()
      and kingdom_member.role = 'guardian'
      and family_member.is_active
      and kingdom_member.is_active
      and (kingdom_member.expires_at is null or kingdom_member.expires_at > now())
  );
$$;

revoke all on function public.is_kingdom_member(uuid) from public, anon;
revoke all on function public.is_kingdom_guardian(uuid) from public, anon;
grant execute on function public.is_kingdom_member(uuid) to authenticated;
grant execute on function public.is_kingdom_guardian(uuid) to authenticated;

alter table public.kingdoms enable row level security;
alter table public.kingdom_members enable row level security;
alter table public.shopping_items enable row level security;

grant select on public.kingdoms, public.kingdom_members to authenticated;
grant select, insert, update, delete on public.shopping_items to authenticated;

create policy "Family members can read kingdoms"
on public.kingdoms for select to authenticated
using ((select public.is_family_member(family_id)));

create policy "Kingdom members can read assignments"
on public.kingdom_members for select to authenticated
using (
  (select public.is_kingdom_member(kingdom_id))
  or exists (
    select 1 from public.kingdoms kingdom
    join public.families family on family.id = kingdom.family_id
    where kingdom.id = kingdom_members.kingdom_id
      and family.owner_id = (select auth.uid())
  )
);

create policy "Kingdom members can read shopping items"
on public.shopping_items for select to authenticated
using ((select public.is_kingdom_member(kingdom_id)));

create policy "Kingdom members can add shopping items"
on public.shopping_items for insert to authenticated
with check (
  (select public.is_kingdom_member(kingdom_id))
  and exists (
    select 1
    from public.kingdom_members kingdom_member
    join public.family_members family_member
      on family_member.id = kingdom_member.member_id
    where kingdom_member.kingdom_id = shopping_items.kingdom_id
      and family_member.id = shopping_items.added_by
      and family_member.user_id = (select auth.uid())
      and kingdom_member.is_active
  )
);

create policy "Kingdom members can update shopping items"
on public.shopping_items for update to authenticated
using ((select public.is_kingdom_member(kingdom_id)))
with check ((select public.is_kingdom_member(kingdom_id)));

create policy "Guardians or authors can delete shopping items"
on public.shopping_items for delete to authenticated
using (
  (select public.is_kingdom_guardian(kingdom_id))
  or exists (
    select 1 from public.family_members member
    where member.id = shopping_items.added_by
      and member.user_id = (select auth.uid())
  )
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'shopping_items'
  ) then
    alter publication supabase_realtime add table public.shopping_items;
  end if;
end;
$$;

notify pgrst, 'reload schema';
