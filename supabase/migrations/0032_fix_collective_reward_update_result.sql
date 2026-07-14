-- Fix the aliased row returned by update_collective_reward.

create or replace function public.update_collective_reward(
  p_suggestion_id uuid,
  p_title text,
  p_description text,
  p_quest_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  suggestion public.reward_suggestions%rowtype;
  result jsonb;
  boss_defeated boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into suggestion
  from public.reward_suggestions
  where id = p_suggestion_id
  for update;

  if suggestion.id is null then
    raise exception 'Collective reward not found';
  end if;
  if not public.is_family_guardian(suggestion.family_id) then
    raise exception 'Only guardians can update collective rewards';
  end if;
  if suggestion.status <> 'approved' then
    raise exception 'Only approved collective rewards can be updated';
  end if;
  if suggestion.archived_at is not null then
    raise exception 'An archived reward cannot be updated';
  end if;
  if suggestion.delivered_at is not null then
    raise exception 'A delivered reward cannot be updated';
  end if;
  if nullif(trim(p_title), '') is null then
    raise exception 'A reward title is required';
  end if;
  if p_quest_count is not null and p_quest_count not between 1 and 100 then
    raise exception 'Quest goal must be between 1 and 100';
  end if;
  if p_quest_count is not null
     and p_quest_count < suggestion.completed_quest_count then
    raise exception 'Quest goal cannot be lower than current progress';
  end if;
  if p_quest_count is null and suggestion.boss_id is null then
    raise exception 'Keep a quest goal because no boss is linked';
  end if;

  select coalesce(boss.status = 'defeated', false)
  into boss_defeated
  from public.bosses boss
  where boss.id = suggestion.boss_id;

  update public.reward_suggestions reward
  set guardian_title = trim(p_title),
      guardian_description = trim(coalesce(p_description, '')),
      guardian_quest_count = p_quest_count,
      fulfilled_at = case
        when (p_quest_count is null
              or reward.completed_quest_count >= p_quest_count)
         and (reward.boss_id is null or coalesce(boss_defeated, false))
          then coalesce(reward.fulfilled_at, now())
        else null
      end,
      updated_at = now()
  where reward.id = suggestion.id
  returning to_jsonb(reward.*) into result;

  return result;
end;
$$;

revoke all on function public.update_collective_reward(uuid, text, text, integer)
  from public, anon;
grant execute on function public.update_collective_reward(uuid, text, text, integer)
  to authenticated;

notify pgrst, 'reload schema';
