-- HomeQuest: explicit active-kingdom reads and boss creation.
-- A member only sees kingdoms granted through kingdom_members.

create or replace function public.list_available_kingdom_quests(
  p_kingdom_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_kingdom_member(p_kingdom_id) then
    raise exception 'Active kingdom membership required';
  end if;

  select coalesce(
    jsonb_agg(row_data order by row_data->>'created_at' desc),
    '[]'::jsonb
  )
  into result
  from (
    select to_jsonb(quest) || jsonb_build_object(
      'assignees', coalesce((
        select jsonb_agg(jsonb_build_object(
          'member_id', member.id,
          'user_id', member.user_id,
          'display_name', profile.display_name,
          'role', kingdom_member.role
        ) order by profile.display_name)
        from public.quest_assignments assignment
        join public.family_members member on member.id = assignment.member_id
        join public.kingdom_members kingdom_member
          on kingdom_member.member_id = member.id
         and kingdom_member.kingdom_id = p_kingdom_id
        join public.profiles profile on profile.id = member.user_id
        where assignment.quest_id = quest.id
          and member.is_active = true
          and kingdom_member.is_active = true
          and (member.expires_at is null or member.expires_at > now())
          and (
            kingdom_member.expires_at is null
            or kingdom_member.expires_at > now()
          )
      ), '[]'::jsonb),
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', skill.id,
          'name', skill.name,
          'icon', skill.icon,
          'xp_reward', reward.xp_reward
        ) order by skill.name)
        from public.quest_skill_rewards reward
        join public.skills skill on skill.id = reward.skill_id
        where reward.quest_id = quest.id
      ), '[]'::jsonb)
    ) row_data
    from public.quests quest
    where quest.kingdom_id = p_kingdom_id
      and public.homequest_quest_is_available(quest.id)
  ) available;

  return result;
end;
$$;

create or replace function public.list_kingdom_bosses(
  p_kingdom_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_kingdom_member(p_kingdom_id) then
    raise exception 'Active kingdom membership required';
  end if;

  select coalesce(jsonb_agg(row_data order by
    case row_data->>'status' when 'active' then 0 else 1 end,
    row_data->>'created_at' desc), '[]'::jsonb)
  into result
  from (
    select to_jsonb(boss) || jsonb_build_object(
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', skill.id,
          'name', skill.name,
          'icon', skill.icon,
          'points', (reward->>'points')::integer
        ) order by skill.name)
        from jsonb_array_elements(boss.skill_rewards) reward
        join public.skills skill on skill.id = reward->>'skill_id'
      ), '[]'::jsonb)
    ) row_data
    from public.bosses boss
    where boss.kingdom_id = p_kingdom_id
  ) boss_rows;

  return result;
end;
$$;

create or replace function public.create_kingdom_boss(
  p_family_id uuid,
  p_kingdom_id uuid,
  p_name text,
  p_emoji text,
  p_element text,
  p_domain_label text,
  p_description text,
  p_max_hp integer,
  p_difficulty integer,
  p_required_level integer,
  p_xp_reward integer,
  p_special_item text,
  p_skill_rewards jsonb,
  p_replace_active boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  created_boss public.bosses%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_kingdom_guardian(p_kingdom_id) then
    raise exception 'Only kingdom guardians can create bosses';
  end if;
  if not exists (
    select 1
    from public.kingdoms kingdom
    where kingdom.id = p_kingdom_id
      and kingdom.family_id = p_family_id
      and kingdom.archived_at is null
  ) then
    raise exception 'Kingdom does not belong to this family';
  end if;
  if nullif(trim(p_name), '') is null
     or nullif(trim(p_emoji), '') is null
     or nullif(trim(p_element), '') is null
     or nullif(trim(p_domain_label), '') is null then
    raise exception 'Boss name, emoji, element and domain are required';
  end if;
  if p_max_hp <= 0 or p_difficulty not between 1 and 5
     or p_required_level < 1 or p_xp_reward < 0 then
    raise exception 'Invalid boss gameplay values';
  end if;
  if jsonb_typeof(p_skill_rewards) <> 'array'
     or jsonb_array_length(p_skill_rewards) not between 2 and 6
     or (select count(distinct reward->>'skill_id')
         from jsonb_array_elements(p_skill_rewards) reward)
        <> jsonb_array_length(p_skill_rewards)
     or exists (
       select 1
       from jsonb_array_elements(p_skill_rewards) reward
       where not exists (
         select 1 from public.skills skill
         where skill.id = reward->>'skill_id'
       ) or coalesce((reward->>'points')::integer, 0) <= 0
     ) then
    raise exception 'A boss requires between two and six valid skills';
  end if;

  if exists (
    select 1 from public.bosses
    where kingdom_id = p_kingdom_id and status = 'active'
  ) then
    if not p_replace_active then
      raise exception 'An active boss already threatens this kingdom';
    end if;
    update public.bosses
    set status = 'expired', ends_at = now()
    where kingdom_id = p_kingdom_id and status = 'active';
  end if;

  insert into public.bosses (
    family_id, kingdom_id, name, emoji, element, domain_label, description,
    max_hp, current_hp, difficulty, required_level, xp_reward,
    special_item, skill_rewards, status, starts_at
  ) values (
    p_family_id, p_kingdom_id, trim(p_name), trim(p_emoji), trim(p_element),
    trim(p_domain_label), trim(coalesce(p_description, '')),
    p_max_hp, p_max_hp, p_difficulty, p_required_level, p_xp_reward,
    trim(coalesce(p_special_item, '')), p_skill_rewards, 'active', now()
  )
  returning * into created_boss;

  return to_jsonb(created_boss) || jsonb_build_object(
    'skill_rewards', (
      select jsonb_agg(jsonb_build_object(
        'skill_id', skill.id,
        'name', skill.name,
        'icon', skill.icon,
        'points', (reward->>'points')::integer
      ) order by skill.name)
      from jsonb_array_elements(created_boss.skill_rewards) reward
      join public.skills skill on skill.id = reward->>'skill_id'
    )
  );
end;
$$;

revoke all on function public.list_available_kingdom_quests(uuid)
  from public, anon;
revoke all on function public.list_kingdom_bosses(uuid)
  from public, anon;
revoke all on function public.create_kingdom_boss(
  uuid, uuid, text, text, text, text, text, integer, integer, integer,
  integer, text, jsonb, boolean
) from public, anon;

grant execute on function public.list_available_kingdom_quests(uuid)
  to authenticated;
grant execute on function public.list_kingdom_bosses(uuid)
  to authenticated;
grant execute on function public.create_kingdom_boss(
  uuid, uuid, text, text, text, text, text, integer, integer, integer,
  integer, text, jsonb, boolean
) to authenticated;

notify pgrst, 'reload schema';
