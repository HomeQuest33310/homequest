-- Schedule quest self-assignment while keeping upcoming quests visible.

alter table public.quests
add column if not exists available_from timestamptz;

create index if not exists quests_kingdom_available_from_idx
on public.quests (kingdom_id, available_from)
where status = 'active';

create function public.create_quest(
  p_family_id uuid,
  p_domain_id uuid,
  p_title text,
  p_real_task text,
  p_description text,
  p_xp_reward integer,
  p_gold_reward integer,
  p_boss_damage integer,
  p_frequency public.quest_frequency,
  p_emoji text,
  p_element text,
  p_difficulty integer,
  p_region_key text,
  p_skill_rewards jsonb,
  p_available_from timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
  v_quest_id uuid;
begin
  v_result := public.create_quest(
    p_family_id,
    p_domain_id,
    p_title,
    p_real_task,
    p_description,
    p_xp_reward,
    p_gold_reward,
    p_boss_damage,
    p_frequency,
    p_emoji,
    p_element,
    p_difficulty,
    p_region_key,
    p_skill_rewards
  );

  v_quest_id := (v_result->>'id')::uuid;

  update public.quests
  set available_from = p_available_from
  where id = v_quest_id;

  return v_result || jsonb_build_object(
    'available_from',
    p_available_from
  );
end;
$$;

create function public.update_kingdom_quest(
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
  p_skill_rewards jsonb,
  p_available_from timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  v_result := public.update_kingdom_quest(
    p_quest_id,
    p_title,
    p_real_task,
    p_description,
    p_domain_id,
    p_xp_reward,
    p_gold_reward,
    p_boss_damage,
    p_frequency,
    p_requires_approval,
    p_emoji,
    p_element,
    p_difficulty,
    p_region_key,
    p_skill_rewards
  );

  update public.quests
  set available_from = p_available_from
  where id = p_quest_id;

  return v_result || jsonb_build_object(
    'available_from',
    p_available_from
  );
end;
$$;

create or replace function public.self_assign_quest(
  p_quest_id uuid
)
returns public.quest_assignments
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quest public.quests;
  v_member public.family_members;
  v_assignment public.quest_assignments;
  v_existing_assignee_names text;
  v_actor_name text;
  v_inserted_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_quest
  from public.quests
  where id = p_quest_id;

  if v_quest.id is null
     or not public.homequest_quest_is_available(v_quest.id) then
    raise exception 'Quest is not currently available';
  end if;

  if v_quest.available_from is not null
     and v_quest.available_from > now() then
    raise exception 'Quest is not available for self-assignment yet';
  end if;

  select * into v_member
  from public.family_members
  where family_id = v_quest.family_id
    and user_id = auth.uid()
    and is_active = true
    and (expires_at is null or expires_at > now())
  limit 1;

  if v_member.id is null then
    raise exception 'You are not an active member of this kingdom';
  end if;

  if v_member.role not in ('guardian', 'adventurer', 'mercenary') then
    raise exception 'This role cannot self-assign quests';
  end if;

  if v_member.role = 'mercenary'
     and v_member.membership_scope = 'domain' then
    if v_member.domain_id is null
       or v_quest.domain_id is distinct from v_member.domain_id then
      raise exception 'This quest is outside your assigned domain';
    end if;
  end if;

  select string_agg(p.display_name, ', ' order by p.display_name)
  into v_existing_assignee_names
  from public.quest_assignments qa
  join public.family_members fm on fm.id = qa.member_id
  join public.profiles p on p.id = fm.user_id
  where qa.quest_id = v_quest.id
    and qa.member_id <> v_member.id;

  insert into public.quest_assignments (quest_id, member_id)
  values (v_quest.id, v_member.id)
  on conflict (quest_id, member_id) do nothing
  returning * into v_assignment;

  get diagnostics v_inserted_count = row_count;

  if v_inserted_count = 0 then
    select * into v_assignment
    from public.quest_assignments
    where quest_id = v_quest.id
      and member_id = v_member.id;
  elsif v_existing_assignee_names is not null then
    select display_name into v_actor_name
    from public.profiles
    where id = v_member.user_id;

    insert into public.guardian_notifications (
      family_id,
      recipient_member_id,
      actor_member_id,
      quest_id,
      kind,
      title,
      body
    )
    select
      v_quest.family_id,
      guardian.id,
      v_member.id,
      v_quest.id,
      'quest_joined',
      'Une mission a été reprise',
      v_actor_name || ' a rejoint « ' || v_quest.title ||
        ' », déjà confiée à ' || v_existing_assignee_names || '.'
    from public.family_members guardian
    where guardian.family_id = v_quest.family_id
      and guardian.role = 'guardian'
      and guardian.is_active = true
      and (guardian.expires_at is null or guardian.expires_at > now())
      and guardian.user_id <> auth.uid()
    on conflict (
      recipient_member_id,
      quest_id,
      actor_member_id,
      kind
    ) do nothing;
  end if;

  return v_assignment;
end;
$$;

revoke all on function public.create_quest(
  uuid, uuid, text, text, text, integer, integer, integer,
  public.quest_frequency, text, text, integer, text, jsonb, timestamptz
) from public, anon;

revoke all on function public.update_kingdom_quest(
  uuid, text, text, text, uuid, integer, integer, integer,
  public.quest_frequency, boolean, text, text, integer, text, jsonb,
  timestamptz
) from public, anon;

revoke all on function public.self_assign_quest(uuid)
from public, anon;

grant execute on function public.create_quest(
  uuid, uuid, text, text, text, integer, integer, integer,
  public.quest_frequency, text, text, integer, text, jsonb, timestamptz
) to authenticated;

grant execute on function public.update_kingdom_quest(
  uuid, text, text, text, uuid, integer, integer, integer,
  public.quest_frequency, boolean, text, text, integer, text, jsonb,
  timestamptz
) to authenticated;

grant execute on function public.self_assign_quest(uuid)
to authenticated;

notify pgrst, 'reload schema';
