-- Let guardians choose which collective reward receives each next approved
-- quest. Existing progress stays attached to its reward.

alter table public.reward_suggestions
add column if not exists priority_rank integer;

with ranked_rewards as (
  select
    reward.id,
    row_number() over (
      partition by reward.family_id
      order by reward.created_at, reward.id
    )::integer as priority_rank
  from public.reward_suggestions reward
  where reward.status = 'approved'
    and reward.archived_at is null
    and reward.guardian_quest_count is not null
    and reward.completed_quest_count < reward.guardian_quest_count
)
update public.reward_suggestions reward
set priority_rank = ranked.priority_rank
from ranked_rewards ranked
where reward.id = ranked.id
  and reward.priority_rank is null;

create index if not exists reward_suggestions_priority_queue_idx
on public.reward_suggestions(family_id, priority_rank, created_at, id)
where status = 'approved'
  and archived_at is null
  and guardian_quest_count is not null;

create or replace function public.assign_collective_reward_priority()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.status = 'approved'
     and new.archived_at is null
     and new.guardian_quest_count is not null
     and new.completed_quest_count < new.guardian_quest_count
     and new.priority_rank is null then
    select coalesce(max(reward.priority_rank), 0) + 1
    into new.priority_rank
    from public.reward_suggestions reward
    where reward.family_id = new.family_id
      and reward.status = 'approved'
      and reward.archived_at is null
      and reward.guardian_quest_count is not null
      and reward.id is distinct from new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists zz_assign_collective_reward_priority
on public.reward_suggestions;

create trigger zz_assign_collective_reward_priority
before insert or update on public.reward_suggestions
for each row
execute function public.assign_collective_reward_priority();

create or replace function public.reorder_collective_rewards(
  p_family_id uuid,
  p_reward_ids uuid[]
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  expected_ids uuid[];
  supplied_ids uuid[];
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can prioritise collective rewards';
  end if;

  perform 1
  from public.families family
  where family.id = p_family_id
  for update;

  select array_agg(reward.id order by reward.id)
  into expected_ids
  from public.reward_suggestions reward
  where reward.family_id = p_family_id
    and reward.status = 'approved'
    and reward.archived_at is null
    and reward.guardian_quest_count is not null
    and reward.completed_quest_count < reward.guardian_quest_count;

  select array_agg(input.id order by input.id)
  into supplied_ids
  from unnest(coalesce(p_reward_ids, array[]::uuid[])) input(id);

  if coalesce(expected_ids, array[]::uuid[])
     is distinct from coalesce(supplied_ids, array[]::uuid[]) then
    raise exception 'The reward priority list is incomplete or invalid';
  end if;

  update public.reward_suggestions reward
  set priority_rank = ordered.priority_rank,
      updated_at = now()
  from (
    select
      input.id,
      input.ordinality::integer as priority_rank
    from unnest(coalesce(p_reward_ids, array[]::uuid[]))
      with ordinality input(id, ordinality)
  ) ordered
  where reward.id = ordered.id
    and reward.family_id = p_family_id;

  return true;
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
  target_wish_id uuid;
begin
  if new.status <> 'approved'
     or old.status = 'approved' then
    return new;
  end if;

  select quest.family_id
  into quest_family_id
  from public.quests quest
  where quest.id = new.quest_id;

  if quest_family_id is null then
    return new;
  end if;

  perform 1
  from public.families family
  where family.id = quest_family_id
  for update;

  select wish.id
  into target_wish_id
  from public.reward_suggestions wish
  where wish.family_id = quest_family_id
    and wish.status = 'approved'
    and wish.archived_at is null
    and wish.guardian_quest_count is not null
    and wish.completed_quest_count < wish.guardian_quest_count
  order by
    wish.priority_rank asc nulls last,
    wish.created_at asc,
    wish.id asc
  limit 1
  for update;

  if target_wish_id is null then
    return new;
  end if;

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
             select 1
             from public.bosses boss
             where boss.id = wish.boss_id
               and boss.status = 'defeated'
           )
         ) then coalesce(wish.fulfilled_at, now())
        else wish.fulfilled_at
      end,
      updated_at = now()
  where wish.id = target_wish_id;

  return new;
end;
$$;

revoke all on function public.assign_collective_reward_priority()
from public, anon, authenticated;
revoke all on function public.reorder_collective_rewards(uuid, uuid[])
from public, anon;
revoke all on function public.progress_collective_reward_wishes()
from public, anon, authenticated;

grant execute on function public.reorder_collective_rewards(uuid, uuid[])
to authenticated;

comment on column public.reward_suggestions.priority_rank is
  'Guardian-defined order for assigning future approved quests.';
comment on function public.reorder_collective_rewards(uuid, uuid[]) is
  'Reorders all unfinished quest-based rewards for a guardian family.';
comment on function public.progress_collective_reward_wishes() is
  'Progresses the highest-priority unfinished collective quest reward.';

notify pgrst, 'reload schema';
