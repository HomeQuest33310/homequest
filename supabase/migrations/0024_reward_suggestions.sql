-- HomeQuest - Suggestions de récompenses proposées par les aventuriers.

do $$
begin
  create type public.reward_suggestion_status as enum (
    'pending',
    'approved',
    'rejected'
  );
exception
  when duplicate_object then null;
end
$$;

create table if not exists public.reward_suggestions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  proposed_by uuid not null references public.family_members(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 80),
  description text not null default '' check (char_length(description) <= 500),
  suggested_quest_count integer not null default 5
    check (suggested_quest_count between 1 and 100),
  status public.reward_suggestion_status not null default 'pending',
  guardian_title text check (
    guardian_title is null or char_length(trim(guardian_title)) between 2 and 80
  ),
  guardian_description text check (
    guardian_description is null or char_length(guardian_description) <= 500
  ),
  guardian_quest_count integer check (
    guardian_quest_count is null or guardian_quest_count between 1 and 100
  ),
  guardian_boss_theme text check (
    guardian_boss_theme is null
    or char_length(trim(guardian_boss_theme)) between 2 and 80
  ),
  reviewed_by uuid references public.family_members(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists reward_suggestions_family_status_idx
  on public.reward_suggestions(family_id, status, created_at desc);

create index if not exists reward_suggestions_proposed_by_idx
  on public.reward_suggestions(proposed_by, created_at desc);

alter table public.reward_suggestions enable row level security;

drop policy if exists "Members can read relevant reward suggestions"
  on public.reward_suggestions;
create policy "Members can read relevant reward suggestions"
on public.reward_suggestions
for select
to authenticated
using (
  public.is_family_guardian(family_id)
  or exists (
    select 1
    from public.family_members member
    where member.id = proposed_by
      and member.user_id = (select auth.uid())
      and member.is_active
  )
);

drop policy if exists "Adventurers can propose their own rewards"
  on public.reward_suggestions;
create policy "Adventurers can propose their own rewards"
on public.reward_suggestions
for insert
to authenticated
with check (
  status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and exists (
    select 1
    from public.family_members member
    where member.id = proposed_by
      and member.family_id = family_id
      and member.user_id = (select auth.uid())
      and member.role in ('adventurer', 'mercenary')
      and member.is_active
      and (member.expires_at is null or member.expires_at > now())
  )
);

drop policy if exists "Guardians can review reward suggestions"
  on public.reward_suggestions;
create policy "Guardians can review reward suggestions"
on public.reward_suggestions
for update
to authenticated
using (public.is_family_guardian(family_id))
with check (public.is_family_guardian(family_id));

create or replace function public.prepare_reward_suggestion_review()
returns trigger
language plpgsql
security invoker
set search_path = public, auth
as $$
declare
  guardian_member_id uuid;
begin
  new.updated_at := now();

  if new.status = 'pending' and old.status <> 'pending' then
    raise exception 'A reviewed suggestion cannot return to pending';
  end if;

  if new.status <> old.status or new.status <> 'pending' then
    select member.id
    into guardian_member_id
    from public.family_members member
    where member.family_id = old.family_id
      and member.user_id = auth.uid()
      and member.role = 'guardian'
      and member.is_active
    limit 1;

    if guardian_member_id is null then
      raise exception 'Only an active guardian can review a suggestion';
    end if;

    new.reviewed_by := guardian_member_id;
    new.reviewed_at := now();
  end if;

  if new.status = 'approved' then
    new.guardian_title := coalesce(nullif(trim(new.guardian_title), ''), old.title);
    new.guardian_description := coalesce(new.guardian_description, old.description);
    new.guardian_quest_count := coalesce(
      new.guardian_quest_count,
      old.suggested_quest_count
    );

    if nullif(trim(new.guardian_boss_theme), '') is null then
      raise exception 'A boss theme is required to approve a suggestion';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists prepare_reward_suggestion_review
  on public.reward_suggestions;
create trigger prepare_reward_suggestion_review
before update on public.reward_suggestions
for each row execute function public.prepare_reward_suggestion_review();

revoke all on table public.reward_suggestions from anon, authenticated;
grant select on table public.reward_suggestions to authenticated;
grant insert (
  family_id,
  proposed_by,
  title,
  description,
  suggested_quest_count
) on public.reward_suggestions to authenticated;
grant update (
  status,
  guardian_title,
  guardian_description,
  guardian_quest_count,
  guardian_boss_theme
) on public.reward_suggestions to authenticated;

revoke all on function public.prepare_reward_suggestion_review()
  from public, anon, authenticated;

notify pgrst, 'reload schema';
