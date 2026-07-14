-- HomeQuest v0.7.0-alpha
-- Heroic quest catalogue metadata and the ten fantasy skill paths.

alter table public.quests
  add column if not exists emoji text not null default '📜',
  add column if not exists element text not null default 'Neutre',
  add column if not exists difficulty integer not null default 1;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'quests_difficulty_check'
      and conrelid = 'public.quests'::regclass
  ) then
    alter table public.quests add constraint quests_difficulty_check
      check (difficulty between 1 and 5);
  end if;
end;
$$;

insert into public.skills (id, name, icon, description)
values
  ('strength', 'Puissance du Titan', '💪', 'Force physique et travaux exigeants.'),
  ('agility', 'Pas du Zéphyr', '🏃', 'Rapidité, précision et mouvement.'),
  ('intelligence', 'Sagesse des Arcanes', '🧠', 'Réflexion, organisation et stratégie.'),
  ('leadership', 'Commandement du Royaume', '👑', 'Initiative, courage et responsabilité.'),
  ('endurance', 'Souffle du Colosse', '⏳', 'Persévérance et résistance dans la durée.'),
  ('dexterity', 'Main de l’Artificier', '✋', 'Habileté manuelle et coordination.'),
  ('cleaning', 'Purification Sacrée', '✨', 'Hygiène, propreté et restauration des lieux.'),
  ('organization', 'Ordre du Royaume', '📦', 'Rangement, classement et structure.'),
  ('cooking', 'Alchimie des Saveurs', '🍳', 'Préparation, créativité et goût.'),
  ('gardening', 'Communion Sylvestre', '🌱', 'Culture, entretien et croissance du vivant.')
on conflict (id) do update set
  name = excluded.name,
  icon = excluded.icon,
  description = excluded.description;

create or replace function public.homequest_skill_level_for_xp(p_xp integer)
returns integer
language sql
immutable
set search_path = public
as $$
  select case
    when greatest(coalesce(p_xp, 0), 0) < 100 then 1
    when p_xp < 300 then 2
    when p_xp < 600 then 3
    when p_xp < 1000 then 4
    else 5
  end;
$$;

revoke all on function public.homequest_skill_level_for_xp(integer)
from public, anon, authenticated;

drop function if exists public.create_quest(
  uuid, uuid, text, text, text, integer, integer, integer, quest_frequency
);

create function public.create_quest(
  p_family_id uuid,
  p_domain_id uuid,
  p_title text,
  p_real_task text,
  p_description text default null,
  p_xp_reward integer default 10,
  p_gold_reward integer default 5,
  p_boss_damage integer default 5,
  p_frequency quest_frequency default 'once',
  p_emoji text default '📜',
  p_element text default 'Neutre',
  p_difficulty integer default 1,
  p_region_key text default 'custom',
  p_skill_rewards jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quest public.quests%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can create quests';
  end if;
  if nullif(trim(p_title), '') is null then raise exception 'Quest title is required'; end if;
  if nullif(trim(p_real_task), '') is null then raise exception 'Real task is required'; end if;
  if nullif(trim(p_emoji), '') is null then raise exception 'Emoji is required'; end if;
  if nullif(trim(p_element), '') is null then raise exception 'Element is required'; end if;
  if p_difficulty not between 1 and 5 then raise exception 'Difficulty must be between 1 and 5'; end if;
  if p_domain_id is not null and not exists (
    select 1 from public.domains
    where id = p_domain_id and family_id = p_family_id
  ) then raise exception 'Domain does not belong to this family'; end if;
  if jsonb_typeof(p_skill_rewards) <> 'array'
     or jsonb_array_length(p_skill_rewards) <> 2 then
    raise exception 'A quest must develop exactly two skills';
  end if;
  if (select count(distinct item->>'skill_id') from jsonb_array_elements(p_skill_rewards) item) <> 2
     or exists (
       select 1 from jsonb_array_elements(p_skill_rewards) item
       where not exists (select 1 from public.skills s where s.id = item->>'skill_id')
          or coalesce((item->>'xp_reward')::integer, 0) <= 0
     ) then raise exception 'Invalid skill rewards'; end if;

  insert into public.quests (
    family_id, created_by, title, real_task, description, domain_id,
    region_key, emoji, element, difficulty, xp_reward, gold_reward,
    boss_damage, frequency, requires_approval, status
  ) values (
    p_family_id, auth.uid(), trim(p_title), trim(p_real_task),
    nullif(trim(coalesce(p_description, '')), ''), p_domain_id,
    nullif(trim(coalesce(p_region_key, 'custom')), ''), trim(p_emoji),
    trim(p_element), p_difficulty, greatest(p_xp_reward, 0),
    greatest(p_gold_reward, 0), greatest(p_boss_damage, 0), p_frequency,
    true, 'active'
  ) returning * into v_quest;

  insert into public.quest_skill_rewards (quest_id, skill_id, xp_reward)
  select v_quest.id, item->>'skill_id', (item->>'xp_reward')::integer
  from jsonb_array_elements(p_skill_rewards) item;

  insert into public.chronicles (family_id, type, title, body)
  values (p_family_id, 'quest_created', 'Une nouvelle quête est apparue',
    'La mission « ' || trim(p_title) || ' » a été ajoutée au registre.');

  return to_jsonb(v_quest);
end;
$$;

drop function if exists public.update_quest(
  uuid, text, text, text, uuid, integer, integer, integer, quest_frequency
);

create function public.update_quest(
  quest_id uuid,
  new_title text,
  new_real_task text,
  new_description text,
  new_domain_id uuid,
  new_xp_reward integer,
  new_gold_reward integer,
  new_boss_damage integer,
  new_frequency quest_frequency,
  new_emoji text,
  new_element text,
  new_difficulty integer,
  new_region_key text,
  new_skill_rewards jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quest public.quests%rowtype;
  v_family_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select family_id into v_family_id from public.quests where id = quest_id;
  if v_family_id is null then raise exception 'Quest not found'; end if;
  if not public.is_family_guardian(v_family_id) then
    raise exception 'Only guardians can update quests';
  end if;
  if nullif(trim(new_title), '') is null or nullif(trim(new_real_task), '') is null then
    raise exception 'Title and real task are required';
  end if;
  if nullif(trim(new_emoji), '') is null or nullif(trim(new_element), '') is null then
    raise exception 'Emoji and element are required';
  end if;
  if new_difficulty not between 1 and 5 then raise exception 'Difficulty must be between 1 and 5'; end if;
  if new_domain_id is not null and not exists (
    select 1 from public.domains where id = new_domain_id and family_id = v_family_id
  ) then raise exception 'Domain does not belong to this family'; end if;
  if jsonb_typeof(new_skill_rewards) <> 'array'
     or jsonb_array_length(new_skill_rewards) <> 2
     or (select count(distinct item->>'skill_id') from jsonb_array_elements(new_skill_rewards) item) <> 2
     or exists (
       select 1 from jsonb_array_elements(new_skill_rewards) item
       where not exists (select 1 from public.skills s where s.id = item->>'skill_id')
          or coalesce((item->>'xp_reward')::integer, 0) <= 0
     ) then raise exception 'Invalid skill rewards'; end if;

  update public.quests set
    title = trim(new_title), real_task = trim(new_real_task),
    description = nullif(trim(coalesce(new_description, '')), ''),
    domain_id = new_domain_id,
    region_key = nullif(trim(coalesce(new_region_key, 'custom')), ''),
    emoji = trim(new_emoji), element = trim(new_element),
    difficulty = new_difficulty, xp_reward = greatest(new_xp_reward, 0),
    gold_reward = greatest(new_gold_reward, 0),
    boss_damage = greatest(new_boss_damage, 0), frequency = new_frequency
  where id = quest_id returning * into v_quest;

  delete from public.quest_skill_rewards where quest_id = v_quest.id;
  insert into public.quest_skill_rewards (quest_id, skill_id, xp_reward)
  select v_quest.id, item->>'skill_id', (item->>'xp_reward')::integer
  from jsonb_array_elements(new_skill_rewards) item;

  return to_jsonb(v_quest);
end;
$$;

create or replace function public.list_available_quests(p_family_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.is_family_member(p_family_id) then
    raise exception 'Active family membership required';
  end if;

  select coalesce(jsonb_agg(row_data order by row_data->>'created_at' desc), '[]'::jsonb)
  into v_result
  from (
    select to_jsonb(q) || jsonb_build_object(
      'assignees', coalesce((
        select jsonb_agg(jsonb_build_object(
          'member_id', fm.id, 'user_id', fm.user_id,
          'display_name', p.display_name, 'role', fm.role
        ) order by p.display_name)
        from public.quest_assignments qa
        join public.family_members fm on fm.id = qa.member_id
        join public.profiles p on p.id = fm.user_id
        where qa.quest_id = q.id and fm.is_active = true
          and (fm.expires_at is null or fm.expires_at > now())
      ), '[]'::jsonb),
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', s.id, 'name', s.name, 'icon', s.icon,
          'xp_reward', qsr.xp_reward
        ) order by s.name)
        from public.quest_skill_rewards qsr
        join public.skills s on s.id = qsr.skill_id
        where qsr.quest_id = q.id
      ), '[]'::jsonb)
    ) row_data
    from public.quests q
    where q.family_id = p_family_id
      and public.homequest_quest_is_available(q.id)
  ) available;
  return v_result;
end;
$$;

create or replace function public.apply_quest_completion_rewards(
  p_completion_id uuid,
  p_reviewer_member_id uuid,
  p_allow_self boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_completion public.quest_completions;
  v_quest public.quests;
  v_member public.family_members;
  v_profile public.profiles;
  v_boss public.bosses;
  v_new_xp integer;
  v_new_level integer;
  v_boss_defeated boolean := false;
begin
  select * into v_completion from public.quest_completions
  where id = p_completion_id for update;
  if v_completion.id is null then raise exception 'Completion not found'; end if;
  if v_completion.status <> 'pending' then raise exception 'Completion has already been reviewed'; end if;
  if not p_allow_self and v_completion.completed_by = p_reviewer_member_id then
    raise exception 'A guardian cannot approve their own quest';
  end if;
  select * into v_quest from public.quests where id = v_completion.quest_id;
  select * into v_member from public.family_members
  where id = v_completion.completed_by for update;
  select * into v_profile from public.profiles where id = v_member.user_id;

  v_new_xp := v_member.xp + v_quest.xp_reward;
  v_new_level := public.homequest_level_for_xp(v_new_xp);
  update public.family_members set xp = v_new_xp,
    gold = gold + v_quest.gold_reward, level = greatest(level, v_new_level)
  where id = v_member.id;

  insert into public.member_skills (member_id, skill_id, xp, level, updated_at)
  select v_member.id, qsr.skill_id, qsr.xp_reward,
    public.homequest_skill_level_for_xp(qsr.xp_reward), now()
  from public.quest_skill_rewards qsr where qsr.quest_id = v_quest.id
  on conflict (member_id, skill_id) do update set
    xp = public.member_skills.xp + excluded.xp,
    level = public.homequest_skill_level_for_xp(public.member_skills.xp + excluded.xp),
    updated_at = now();

  select * into v_boss from public.bosses
  where family_id = v_quest.family_id and status = 'active'
    and (ends_at is null or ends_at > now())
  order by starts_at desc limit 1 for update;
  if v_boss.id is not null then
    update public.bosses set
      current_hp = greatest(0, current_hp - v_quest.boss_damage),
      status = case when current_hp - v_quest.boss_damage <= 0
        then 'defeated'::boss_status else status end
    where id = v_boss.id;
    insert into public.boss_damage_events (boss_id, completion_id, damage)
    values (v_boss.id, v_completion.id, v_quest.boss_damage);
    v_boss_defeated := v_boss.current_hp - v_quest.boss_damage <= 0;
  end if;

  update public.quest_completions set status = 'approved',
    approved_by = p_reviewer_member_id, approved_at = now(), rewarded_at = now(),
    rejection_reason = null where id = v_completion.id;
  insert into public.chronicles (family_id, type, title, body)
  values (v_quest.family_id, 'quest_completed',
    v_profile.display_name || ' a accompli « ' || v_quest.title || ' »',
    '+' || v_quest.xp_reward || ' XP, +' || v_quest.gold_reward ||
      ' or et ' || v_quest.boss_damage || ' dégâts au boss.');
  return jsonb_build_object(
    'completion_id', v_completion.id, 'xp_reward', v_quest.xp_reward,
    'gold_reward', v_quest.gold_reward,
    'boss_damage', case when v_boss.id is null then 0 else v_quest.boss_damage end,
    'new_xp', v_new_xp, 'new_level', greatest(v_member.level, v_new_level),
    'boss_defeated', v_boss_defeated
  );
end;
$$;

revoke all on function public.create_quest(
  uuid, uuid, text, text, text, integer, integer, integer, quest_frequency,
  text, text, integer, text, jsonb
) from public, anon;
grant execute on function public.create_quest(
  uuid, uuid, text, text, text, integer, integer, integer, quest_frequency,
  text, text, integer, text, jsonb
) to authenticated;

revoke all on function public.update_quest(
  uuid, text, text, text, uuid, integer, integer, integer, quest_frequency,
  text, text, integer, text, jsonb
) from public, anon;
grant execute on function public.update_quest(
  uuid, text, text, text, uuid, integer, integer, integer, quest_frequency,
  text, text, integer, text, jsonb
) to authenticated;

revoke all on function public.list_available_quests(uuid) from public, anon;
grant execute on function public.list_available_quests(uuid) to authenticated;
revoke all on function public.apply_quest_completion_rewards(uuid, uuid, boolean)
from public, anon, authenticated;

notify pgrst, 'reload schema';
