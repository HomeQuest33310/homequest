-- Allow a kingdom guardian to update every editable quest parameter.
-- Assignment and archival remain separate explicit workflows.

create or replace function public.update_kingdom_quest(
  p_quest_id uuid,
  p_title text,
  p_real_task text,
  p_description text,
  p_domain_id uuid,
  p_xp_reward integer,
  p_gold_reward integer,
  p_boss_damage integer,
  p_frequency public.quest_frequency,
  p_requires_approval boolean,
  p_emoji text,
  p_element text,
  p_difficulty integer,
  p_region_key text,
  p_skill_rewards jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quest public.quests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_quest
  from public.quests
  where id = p_quest_id
  for update;

  if v_quest.id is null then
    raise exception 'Quest not found';
  end if;
  if v_quest.status = 'archived' then
    raise exception 'Archived quests cannot be modified';
  end if;
  if not public.is_kingdom_guardian(v_quest.kingdom_id) then
    raise exception 'Only this kingdom''s guardians can update quests';
  end if;
  if nullif(trim(p_title), '') is null
     or nullif(trim(p_real_task), '') is null then
    raise exception 'Title and real task are required';
  end if;
  if nullif(trim(p_emoji), '') is null
     or nullif(trim(p_element), '') is null then
    raise exception 'Emoji and element are required';
  end if;
  if p_difficulty not between 1 and 5 then
    raise exception 'Difficulty must be between 1 and 5';
  end if;
  if p_xp_reward < 0 or p_gold_reward < 0 or p_boss_damage < 0 then
    raise exception 'Quest rewards cannot be negative';
  end if;
  if p_requires_approval is null then
    raise exception 'Approval mode is required';
  end if;
  if p_domain_id is null or not exists (
    select 1
    from public.domains domain
    where domain.id = p_domain_id
      and domain.kingdom_id = v_quest.kingdom_id
      and domain.archived_at is null
  ) then
    raise exception 'Domain does not belong to this kingdom';
  end if;
  if jsonb_typeof(p_skill_rewards) <> 'array'
     or jsonb_array_length(p_skill_rewards) <> 2
     or (
       select count(distinct item->>'skill_id')
       from jsonb_array_elements(p_skill_rewards) item
     ) <> 2
     or exists (
       select 1
       from jsonb_array_elements(p_skill_rewards) item
       where not exists (
         select 1
         from public.skills skill
         where skill.id = item->>'skill_id'
       )
       or coalesce((item->>'xp_reward')::integer, 0) <= 0
     ) then
    raise exception 'Exactly two valid skill rewards are required';
  end if;

  update public.quests
  set
    title = trim(p_title),
    real_task = trim(p_real_task),
    description = nullif(trim(coalesce(p_description, '')), ''),
    domain_id = p_domain_id,
    region_key = nullif(trim(coalesce(p_region_key, 'custom')), ''),
    emoji = trim(p_emoji),
    element = trim(p_element),
    difficulty = p_difficulty,
    xp_reward = p_xp_reward,
    gold_reward = p_gold_reward,
    boss_damage = p_boss_damage,
    frequency = p_frequency,
    requires_approval = p_requires_approval
  where id = p_quest_id
  returning * into v_quest;

  delete from public.quest_skill_rewards
  where quest_id = v_quest.id;

  insert into public.quest_skill_rewards (quest_id, skill_id, xp_reward)
  select
    v_quest.id,
    item->>'skill_id',
    (item->>'xp_reward')::integer
  from jsonb_array_elements(p_skill_rewards) item;

  return to_jsonb(v_quest) || jsonb_build_object(
    'skill_rewards', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'skill_id', skill.id,
        'name', skill.name,
        'icon', skill.icon,
        'xp_reward', reward.xp_reward
      ) order by skill.name), '[]'::jsonb)
      from public.quest_skill_rewards reward
      join public.skills skill on skill.id = reward.skill_id
      where reward.quest_id = v_quest.id
    ),
    'assignees', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'member_id', member.id,
        'user_id', member.user_id,
        'display_name', profile.display_name,
        'role', kingdom_member.role
      ) order by profile.display_name), '[]'::jsonb)
      from public.quest_assignments assignment
      join public.family_members member on member.id = assignment.member_id
      join public.kingdom_members kingdom_member
        on kingdom_member.member_id = member.id
       and kingdom_member.kingdom_id = v_quest.kingdom_id
      join public.profiles profile on profile.id = member.user_id
      where assignment.quest_id = v_quest.id
        and member.is_active
        and kingdom_member.is_active
    )
  );
end;
$$;

revoke all on function public.update_kingdom_quest(
  uuid, text, text, text, uuid, integer, integer, integer,
  public.quest_frequency, boolean, text, text, integer, text, jsonb
) from public, anon;

grant execute on function public.update_kingdom_quest(
  uuid, text, text, text, uuid, integer, integer, integer,
  public.quest_frequency, boolean, text, text, integer, text, jsonb
) to authenticated;

notify pgrst, 'reload schema';
