-- Qualify quest_skill_rewards.quest_id so PL/pgSQL does not confuse it with
-- the update_quest input parameter of the same name.

create or replace function public.update_quest(
  quest_id uuid,
  new_title text,
  new_real_task text,
  new_description text,
  new_domain_id uuid,
  new_xp_reward integer,
  new_gold_reward integer,
  new_boss_damage integer,
  new_frequency public.quest_frequency,
  new_emoji text,
  new_element text,
  new_difficulty integer,
  new_region_key text,
  new_skill_rewards jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quest public.quests%rowtype;
  v_family_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select q.family_id
  into v_family_id
  from public.quests q
  where q.id = quest_id;

  if v_family_id is null then
    raise exception 'Quest not found';
  end if;

  if not public.is_family_guardian(v_family_id) then
    raise exception 'Only guardians can update quests';
  end if;

  if nullif(trim(new_title), '') is null
     or nullif(trim(new_real_task), '') is null then
    raise exception 'Title and real task are required';
  end if;

  if nullif(trim(new_emoji), '') is null
     or nullif(trim(new_element), '') is null then
    raise exception 'Emoji and element are required';
  end if;

  if new_difficulty not between 1 and 5 then
    raise exception 'Difficulty must be between 1 and 5';
  end if;

  if new_domain_id is not null and not exists (
    select 1
    from public.domains d
    where d.id = new_domain_id
      and d.family_id = v_family_id
  ) then
    raise exception 'Domain does not belong to this family';
  end if;

  if jsonb_typeof(new_skill_rewards) <> 'array'
     or jsonb_array_length(new_skill_rewards) <> 2
     or (
       select count(distinct item->>'skill_id')
       from jsonb_array_elements(new_skill_rewards) item
     ) <> 2
     or exists (
       select 1
       from jsonb_array_elements(new_skill_rewards) item
       where not exists (
         select 1
         from public.skills s
         where s.id = item->>'skill_id'
       )
       or coalesce((item->>'xp_reward')::integer, 0) <= 0
     ) then
    raise exception 'Invalid skill rewards';
  end if;

  update public.quests q
  set
    title = trim(new_title),
    real_task = trim(new_real_task),
    description = nullif(trim(coalesce(new_description, '')), ''),
    domain_id = new_domain_id,
    region_key = nullif(trim(coalesce(new_region_key, 'custom')), ''),
    emoji = trim(new_emoji),
    element = trim(new_element),
    difficulty = new_difficulty,
    xp_reward = greatest(new_xp_reward, 0),
    gold_reward = greatest(new_gold_reward, 0),
    boss_damage = greatest(new_boss_damage, 0),
    frequency = new_frequency
  where q.id = quest_id
  returning q.* into v_quest;

  delete from public.quest_skill_rewards qsr
  where qsr.quest_id = v_quest.id;

  insert into public.quest_skill_rewards (quest_id, skill_id, xp_reward)
  select
    v_quest.id,
    item->>'skill_id',
    (item->>'xp_reward')::integer
  from jsonb_array_elements(new_skill_rewards) item;

  return to_jsonb(v_quest);
end;
$$;

comment on function public.update_quest(
  uuid,
  text,
  text,
  text,
  uuid,
  integer,
  integer,
  integer,
  public.quest_frequency,
  text,
  text,
  integer,
  text,
  jsonb
) is 'Updates a quest and replaces its two skill rewards.';
