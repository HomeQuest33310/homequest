-- Collective reward wishes: quest goals, optional boss invocation and progress.

alter table public.reward_suggestions
  add column if not exists boss_id uuid references public.bosses(id) on delete set null,
  add column if not exists completed_quest_count integer not null default 0,
  add column if not exists fulfilled_at timestamptz;

alter table public.reward_suggestions
  drop constraint if exists reward_suggestions_guardian_quest_count_check;

alter table public.reward_suggestions
  add constraint reward_suggestions_guardian_quest_count_check
  check (
    guardian_quest_count is null
    or guardian_quest_count between 1 and 100
  );

create index if not exists reward_suggestions_boss_id_idx
  on public.reward_suggestions(boss_id)
  where boss_id is not null;

drop policy if exists "Members can read relevant reward suggestions"
  on public.reward_suggestions;
create policy "Members can read relevant reward suggestions"
on public.reward_suggestions
for select
to authenticated
using (
  public.is_family_guardian(family_id)
  or (
    status = 'approved'
    and public.is_family_member(family_id)
  )
  or exists (
    select 1
    from public.family_members member
    where member.id = proposed_by
      and member.user_id = (select auth.uid())
      and member.is_active
  )
);

-- Reviews are performed atomically by review_reward_suggestion.
revoke update on table public.reward_suggestions from authenticated;

drop trigger if exists prepare_reward_suggestion_review
  on public.reward_suggestions;
drop function if exists public.prepare_reward_suggestion_review();

create or replace function public.review_reward_suggestion(
  p_suggestion_id uuid,
  p_status public.reward_suggestion_status,
  p_title text,
  p_description text,
  p_quest_count integer,
  p_boss jsonb,
  p_replace_active_boss boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  suggestion public.reward_suggestions%rowtype;
  guardian_member_id uuid;
  created_boss jsonb;
  created_boss_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into suggestion
  from public.reward_suggestions
  where id = p_suggestion_id
  for update;

  if suggestion.id is null then
    raise exception 'Reward suggestion not found';
  end if;

  if not public.is_family_guardian(suggestion.family_id) then
    raise exception 'Only guardians can review reward suggestions';
  end if;

  select member.id into guardian_member_id
  from public.family_members member
  where member.family_id = suggestion.family_id
    and member.user_id = auth.uid()
    and member.role = 'guardian'
    and member.is_active
  limit 1;

  if p_status = 'rejected' then
    update public.reward_suggestions
    set status = 'rejected',
        guardian_title = coalesce(nullif(trim(p_title), ''), title),
        guardian_description = trim(coalesce(p_description, '')),
        guardian_quest_count = null,
        guardian_boss_theme = null,
        boss_id = null,
        reviewed_by = guardian_member_id,
        reviewed_at = now(),
        updated_at = now()
    where id = suggestion.id
    returning to_jsonb(reward_suggestions.*) into created_boss;
    return created_boss;
  end if;

  if p_status <> 'approved' then
    raise exception 'Unsupported review status';
  end if;

  if nullif(trim(p_title), '') is null then
    raise exception 'A reward title is required';
  end if;

  if p_quest_count is not null and p_quest_count not between 1 and 100 then
    raise exception 'Quest goal must be between 1 and 100';
  end if;

  if p_quest_count is null and p_boss is null then
    raise exception 'Choose a quest goal, a boss, or both';
  end if;

  if p_boss is not null then
    created_boss := public.create_family_boss(
      suggestion.family_id,
      p_boss->>'name',
      p_boss->>'emoji',
      p_boss->>'element',
      p_boss->>'domain_label',
      p_boss->>'description',
      (p_boss->>'max_hp')::integer,
      (p_boss->>'difficulty')::integer,
      (p_boss->>'required_level')::integer,
      (p_boss->>'xp_reward')::integer,
      p_boss->>'special_item',
      p_boss->'skill_rewards',
      p_replace_active_boss
    );
    created_boss_id := (created_boss->>'id')::uuid;
  end if;

  update public.reward_suggestions
  set status = 'approved',
      guardian_title = trim(p_title),
      guardian_description = trim(coalesce(p_description, '')),
      guardian_quest_count = p_quest_count,
      guardian_boss_theme = case
        when p_boss is null then null
        else p_boss->>'name'
      end,
      boss_id = created_boss_id,
      completed_quest_count = 0,
      fulfilled_at = null,
      reviewed_by = guardian_member_id,
      reviewed_at = now(),
      updated_at = now()
  where id = suggestion.id
  returning to_jsonb(reward_suggestions.*) into created_boss;

  return created_boss;
end;
$$;

create or replace function public.progress_collective_reward_wishes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  quest_family_id uuid;
begin
  if new.status <> 'approved'
     or old.status = 'approved' then
    return new;
  end if;

  select quest.family_id into quest_family_id
  from public.quests quest
  where quest.id = new.quest_id;

  update public.reward_suggestions wish
  set completed_quest_count = least(
        wish.completed_quest_count + 1,
        wish.guardian_quest_count
      ),
      fulfilled_at = case
        when wish.completed_quest_count + 1 >= wish.guardian_quest_count
         and (
           wish.boss_id is null
           or exists (
             select 1 from public.bosses boss
             where boss.id = wish.boss_id and boss.status = 'defeated'
           )
         ) then coalesce(wish.fulfilled_at, now())
        else wish.fulfilled_at
      end,
      updated_at = now()
  where wish.family_id = quest_family_id
    and wish.status = 'approved'
    and wish.guardian_quest_count is not null
    and wish.completed_quest_count < wish.guardian_quest_count;

  return new;
end;
$$;

drop trigger if exists progress_collective_reward_wishes
  on public.quest_completions;
create trigger progress_collective_reward_wishes
after update of status on public.quest_completions
for each row execute function public.progress_collective_reward_wishes();

create or replace function public.complete_boss_reward_wishes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'defeated' and old.status <> 'defeated' then
    update public.reward_suggestions wish
    set fulfilled_at = coalesce(wish.fulfilled_at, now()),
        updated_at = now()
    where wish.boss_id = new.id
      and wish.status = 'approved'
      and (
        wish.guardian_quest_count is null
        or wish.completed_quest_count >= wish.guardian_quest_count
      );
  end if;
  return new;
end;
$$;

drop trigger if exists complete_boss_reward_wishes on public.bosses;
create trigger complete_boss_reward_wishes
after update of status on public.bosses
for each row execute function public.complete_boss_reward_wishes();

revoke all on function public.review_reward_suggestion(
  uuid, public.reward_suggestion_status, text, text, integer, jsonb, boolean
) from public, anon;
grant execute on function public.review_reward_suggestion(
  uuid, public.reward_suggestion_status, text, text, integer, jsonb, boolean
) to authenticated;

revoke all on function public.progress_collective_reward_wishes()
  from public, anon, authenticated;
revoke all on function public.complete_boss_reward_wishes()
  from public, anon, authenticated;

notify pgrst, 'reload schema';
