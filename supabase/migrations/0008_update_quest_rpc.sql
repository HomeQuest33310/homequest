-- HomeQuest v0.3.1-alpha
-- Quest update and archive RPC

create or replace function public.update_quest(
  quest_id uuid,
  new_title text,
  new_real_task text,
  new_description text,
  new_domain_id uuid,
  new_xp_reward int,
  new_gold_reward int,
  new_boss_damage int,
  new_frequency quest_frequency
)
returns quests
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_quest quests;
  target_family_id uuid;
begin
  select family_id into target_family_id
  from quests
  where id = quest_id;

  if target_family_id is null then
    raise exception 'Quest not found';
  end if;

  if not is_family_guardian(target_family_id) then
    raise exception 'Only guardians can update quests';
  end if;

  update quests
  set
    title = new_title,
    real_task = new_real_task,
    description = new_description,
    domain_id = new_domain_id,
    xp_reward = new_xp_reward,
    gold_reward = new_gold_reward,
    boss_damage = new_boss_damage,
    frequency = new_frequency
  where id = quest_id
  returning * into updated_quest;

  return updated_quest;
end;
$$;

create or replace function public.archive_quest(
  quest_id uuid
)
returns quests
language plpgsql
security definer
set search_path = public
as $$
declare
  archived_quest quests;
  target_family_id uuid;
begin
  select family_id into target_family_id
  from quests
  where id = quest_id;

  if target_family_id is null then
    raise exception 'Quest not found';
  end if;

  if not is_family_guardian(target_family_id) then
    raise exception 'Only guardians can archive quests';
  end if;

  update quests
  set status = 'archived'
  where id = quest_id
  returning * into archived_quest;

  return archived_quest;
end;
$$;