-- HomeQuest - Le catalogue heroique contient des quetes allant jusqu'a 500 XP.

alter table public.voluntary_quest_requests
  drop constraint if exists voluntary_quest_requests_xp_reward_check;

alter table public.voluntary_quest_requests
  add constraint voluntary_quest_requests_xp_reward_check
  check (xp_reward between 1 and 500);

do $$
declare
  v_definition text;
  v_updated_definition text;
begin
  select pg_get_functiondef(p.oid)
  into v_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'submit_voluntary_quest_request'
    and pg_get_function_identity_arguments(p.oid) =
      'p_kingdom_id uuid, p_domain_id uuid, p_catalog_id integer, p_title text, p_real_task text, p_description text, p_emoji text, p_element text, p_difficulty integer, p_region_key text, p_xp_reward integer, p_gold_reward integer, p_boss_damage integer, p_skill_rewards jsonb, p_already_completed boolean, p_requester_note text';

  if v_definition is null then
    raise exception 'submit_voluntary_quest_request function not found';
  end if;

  v_updated_definition := replace(
    replace(
      v_definition,
      'p_xp_reward not between 1 and 100',
      'p_xp_reward not between 1 and 500'
    ),
    'p_xp_reward NOT BETWEEN 1 AND 100',
    'p_xp_reward NOT BETWEEN 1 AND 500'
  );

  if v_updated_definition = v_definition then
    raise exception 'XP validation clause was not found';
  end if;

  execute v_updated_definition;
end;
$$;

notify pgrst, 'reload schema';
