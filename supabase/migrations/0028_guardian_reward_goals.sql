-- Plusieurs objectifs collectifs peuvent progresser en parallèle.
-- Les Gardiens peuvent créer des récompenses officielles et plusieurs
-- objectifs peuvent être rattachés au même boss actif.

alter table public.reward_suggestions
  add column if not exists created_by_guardian boolean not null default false;

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
  result jsonb;
  selected_boss_id uuid;
  selected_boss_name text;
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
    returning to_jsonb(reward_suggestions.*) into result;
    return result;
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
    if nullif(p_boss->>'existing_boss_id', '') is not null then
      select boss.id, boss.name
      into selected_boss_id, selected_boss_name
      from public.bosses boss
      where boss.id = (p_boss->>'existing_boss_id')::uuid
        and boss.family_id = suggestion.family_id
        and boss.status = 'active';

      if selected_boss_id is null then
        raise exception 'The selected active boss is unavailable';
      end if;
    else
      result := public.create_family_boss(
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
      selected_boss_id := (result->>'id')::uuid;
      selected_boss_name := result->>'name';
    end if;
  end if;

  update public.reward_suggestions
  set status = 'approved',
      guardian_title = trim(p_title),
      guardian_description = trim(coalesce(p_description, '')),
      guardian_quest_count = p_quest_count,
      guardian_boss_theme = selected_boss_name,
      boss_id = selected_boss_id,
      completed_quest_count = 0,
      fulfilled_at = null,
      reviewed_by = guardian_member_id,
      reviewed_at = now(),
      updated_at = now()
  where id = suggestion.id
  returning to_jsonb(reward_suggestions.*) into result;

  return result;
end;
$$;

create or replace function public.create_guardian_reward_goal(
  p_family_id uuid,
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
  guardian_member_id uuid;
  result jsonb;
  selected_boss_id uuid;
  selected_boss_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can create kingdom rewards';
  end if;

  select member.id into guardian_member_id
  from public.family_members member
  where member.family_id = p_family_id
    and member.user_id = auth.uid()
    and member.role = 'guardian'
    and member.is_active
  limit 1;

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
    if nullif(p_boss->>'existing_boss_id', '') is not null then
      select boss.id, boss.name
      into selected_boss_id, selected_boss_name
      from public.bosses boss
      where boss.id = (p_boss->>'existing_boss_id')::uuid
        and boss.family_id = p_family_id
        and boss.status = 'active';

      if selected_boss_id is null then
        raise exception 'The selected active boss is unavailable';
      end if;
    else
      result := public.create_family_boss(
        p_family_id,
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
      selected_boss_id := (result->>'id')::uuid;
      selected_boss_name := result->>'name';
    end if;
  end if;

  insert into public.reward_suggestions (
    family_id,
    proposed_by,
    title,
    description,
    suggested_quest_count,
    status,
    guardian_title,
    guardian_description,
    guardian_quest_count,
    guardian_boss_theme,
    boss_id,
    reviewed_by,
    reviewed_at,
    created_by_guardian
  ) values (
    p_family_id,
    guardian_member_id,
    trim(p_title),
    trim(coalesce(p_description, '')),
    coalesce(p_quest_count, 1),
    'approved',
    trim(p_title),
    trim(coalesce(p_description, '')),
    p_quest_count,
    selected_boss_name,
    selected_boss_id,
    guardian_member_id,
    now(),
    true
  )
  returning to_jsonb(reward_suggestions.*) into result;

  return result;
end;
$$;

revoke all on function public.create_guardian_reward_goal(
  uuid, text, text, integer, jsonb, boolean
) from public, anon;
grant execute on function public.create_guardian_reward_goal(
  uuid, text, text, integer, jsonb, boolean
) to authenticated;

notify pgrst, 'reload schema';
