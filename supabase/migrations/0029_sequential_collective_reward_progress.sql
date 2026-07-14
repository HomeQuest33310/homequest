-- Count each approved quest toward exactly one collective reward goal.
-- Goals are processed in creation order within each kingdom.

create index if not exists reward_suggestions_sequential_progress_idx
  on public.reward_suggestions(family_id, created_at, id)
  where status = 'approved'
    and guardian_quest_count is not null;

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

  -- Serialize progress within one kingdom. Without this lock, two quests
  -- approved simultaneously could both choose the same almost-complete goal.
  perform 1
  from public.families family
  where family.id = quest_family_id
  for update;

  select wish.id
  into target_wish_id
  from public.reward_suggestions wish
  where wish.family_id = quest_family_id
    and wish.status = 'approved'
    and wish.guardian_quest_count is not null
    and wish.completed_quest_count < wish.guardian_quest_count
  order by wish.created_at asc, wish.id asc
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

revoke all on function public.progress_collective_reward_wishes()
  from public, anon, authenticated;

comment on function public.progress_collective_reward_wishes() is
  'Progresses only the oldest approved collective quest goal in a kingdom.';

notify pgrst, 'reload schema';
