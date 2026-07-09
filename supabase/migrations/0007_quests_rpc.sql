-- HomeQuest
-- Migration 0007 - Quest creation RPC
--
-- Adds an atomic RPC for guardians to create quests safely.

alter type chronicle_type add value if not exists 'quest_created';

create or replace function public.create_quest(
  p_family_id uuid,
  p_domain_id uuid,
  p_title text,
  p_real_task text,
  p_description text default null,
  p_xp_reward int default 10,
  p_gold_reward int default 5,
  p_boss_damage int default 5,
  p_frequency quest_frequency default 'once'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_quest public.quests%rowtype;
  v_domain_name text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can create quests';
  end if;

  if nullif(trim(p_title), '') is null then
    raise exception 'Quest title is required';
  end if;

  if nullif(trim(p_real_task), '') is null then
    raise exception 'Real task is required';
  end if;

  if p_domain_id is not null then
    select name into v_domain_name
    from public.domains
    where id = p_domain_id
      and family_id = p_family_id;

    if v_domain_name is null then
      raise exception 'Domain does not belong to this family';
    end if;
  end if;

  insert into public.quests (
    family_id,
    created_by,
    title,
    real_task,
    description,
    domain_id,
    xp_reward,
    gold_reward,
    boss_damage,
    frequency,
    requires_approval,
    status
  ) values (
    p_family_id,
    v_user_id,
    trim(p_title),
    trim(p_real_task),
    nullif(trim(coalesce(p_description, '')), ''),
    p_domain_id,
    greatest(coalesce(p_xp_reward, 10), 0),
    greatest(coalesce(p_gold_reward, 5), 0),
    greatest(coalesce(p_boss_damage, 5), 0),
    coalesce(p_frequency, 'once'),
    true,
    'active'
  ) returning * into v_quest;

  insert into public.chronicles (family_id, type, title, body)
  values (
    p_family_id,
    'quest_created',
    'Une nouvelle quête est apparue',
    'La mission "' || trim(p_title) || '" a été ajoutée au registre des quêtes.'
  );

  return to_jsonb(v_quest);
end;
$$;

grant execute on function public.create_quest(uuid, uuid, text, text, text, int, int, int, quest_frequency) to authenticated;
