-- Make recurring quest availability participant-specific and let members
-- leave an assignment while preserving completion and reward history.

create or replace function public.homequest_quest_is_available_for_member(
  p_quest_id uuid,
  p_member_id uuid
)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.quests q
    where q.id = p_quest_id
      and q.status = 'active'
      and not exists (
        select 1
        from public.quest_completions qc
        where qc.quest_id = q.id
          and (
            (
              q.frequency = 'once'
              and (
                qc.status = 'pending'
                or qc.status = 'approved'
              )
            )
            or (
              q.frequency in ('daily', 'weekly')
              and qc.completed_by = p_member_id
              and (
                qc.status = 'pending'
                or (
                  qc.status = 'approved'
                  and (
                    (
                      q.frequency = 'daily'
                      and qc.completed_at::date = current_date
                    )
                    or (
                      q.frequency = 'weekly'
                      and date_trunc('week', qc.completed_at)
                        = date_trunc('week', now())
                    )
                  )
                )
              )
            )
          )
      )
  );
$$;

create or replace function public.list_my_missions(p_family_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_member public.family_members;
  v_result jsonb;
begin
  select * into v_member
  from public.family_members
  where family_id = p_family_id
    and user_id = auth.uid()
    and is_active = true
    and (expires_at is null or expires_at > now())
  limit 1;

  if v_member.id is null then
    raise exception 'Active family membership required';
  end if;

  select coalesce(
    jsonb_agg(row_data order by row_data->>'assigned_at' desc),
    '[]'::jsonb
  )
  into v_result
  from (
    select jsonb_build_object(
      'assignment_id', qa.id,
      'assigned_at', qa.assigned_at,
      'is_available_now',
        public.homequest_quest_is_available_for_member(q.id, v_member.id),
      'quest', to_jsonb(q),
      'completion', (
        select to_jsonb(qc)
        from public.quest_completions qc
        where qc.quest_id = q.id
          and qc.completed_by = v_member.id
        order by qc.completed_at desc
        limit 1
      )
    ) as row_data
    from public.quest_assignments qa
    join public.quests q on q.id = qa.quest_id
    where qa.member_id = v_member.id
      and q.family_id = p_family_id
      and q.status = 'active'
      and (
        q.frequency in ('daily', 'weekly')
        or public.homequest_quest_is_available_for_member(q.id, v_member.id)
        or exists (
          select 1
          from public.quest_completions pending
          where pending.quest_id = q.id
            and pending.completed_by = v_member.id
            and pending.status = 'pending'
        )
      )
  ) missions;

  return v_result;
end;
$$;

create or replace function public.list_available_quests(p_family_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_member public.family_members;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_member
  from public.family_members
  where family_id = p_family_id
    and user_id = auth.uid()
    and is_active = true
    and (expires_at is null or expires_at > now())
  limit 1;

  if v_member.id is null then
    raise exception 'Active family membership required';
  end if;

  select coalesce(
    jsonb_agg(row_data order by row_data->>'created_at' desc),
    '[]'::jsonb
  )
  into v_result
  from (
    select to_jsonb(q) || jsonb_build_object(
      'assignees', coalesce((
        select jsonb_agg(jsonb_build_object(
          'member_id', fm.id,
          'user_id', fm.user_id,
          'display_name', p.display_name,
          'role', fm.role
        ) order by p.display_name)
        from public.quest_assignments qa
        join public.family_members fm on fm.id = qa.member_id
        join public.profiles p on p.id = fm.user_id
        where qa.quest_id = q.id
          and fm.is_active = true
          and (fm.expires_at is null or fm.expires_at > now())
      ), '[]'::jsonb),
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', s.id,
          'name', s.name,
          'icon', s.icon,
          'xp_reward', qsr.xp_reward
        ) order by s.name)
        from public.quest_skill_rewards qsr
        join public.skills s on s.id = qsr.skill_id
        where qsr.quest_id = q.id
      ), '[]'::jsonb)
    ) row_data
    from public.quests q
    where q.family_id = p_family_id
      and public.homequest_quest_is_available_for_member(q.id, v_member.id)
  ) available;

  return v_result;
end;
$$;

create or replace function public.list_available_kingdom_quests(
  p_kingdom_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_member public.family_members;
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select member.* into v_member
  from public.family_members member
  join public.kingdom_members kingdom_member
    on kingdom_member.member_id = member.id
  where kingdom_member.kingdom_id = p_kingdom_id
    and member.user_id = auth.uid()
    and member.is_active = true
    and kingdom_member.is_active = true
    and (member.expires_at is null or member.expires_at > now())
    and (
      kingdom_member.expires_at is null
      or kingdom_member.expires_at > now()
    )
  limit 1;

  if v_member.id is null then
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
        join public.family_members member
          on member.id = assignment.member_id
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
      and public.homequest_quest_is_available_for_member(
        quest.id,
        v_member.id
      )
  ) available;

  return result;
end;
$$;

create or replace function public.self_assign_quest(p_quest_id uuid)
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

  if v_quest.id is null or v_quest.status <> 'active' then
    raise exception 'Quest is not currently available';
  end if;

  if v_quest.available_from is not null and v_quest.available_from > now() then
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

  if not public.homequest_quest_is_available_for_member(
    v_quest.id,
    v_member.id
  ) then
    raise exception 'Quest is not currently available';
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
      'Une mission a ete reprise',
      v_actor_name || ' a rejoint "' || v_quest.title ||
        '", deja confiee a ' || v_existing_assignee_names || '.'
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

create or replace function public.leave_quest(p_quest_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_member public.family_members;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select member.* into v_member
  from public.family_members member
  join public.quests quest on quest.family_id = member.family_id
  where quest.id = p_quest_id
    and member.user_id = auth.uid()
    and member.is_active = true
    and (member.expires_at is null or member.expires_at > now())
  limit 1;

  if v_member.id is null then
    raise exception 'Active membership required';
  end if;

  if exists (
    select 1
    from public.quest_completions completion
    where completion.quest_id = p_quest_id
      and completion.completed_by = v_member.id
      and completion.status = 'pending'
  ) then
    raise exception 'A mission awaiting validation cannot be left';
  end if;

  delete from public.quest_assignments assignment
  where assignment.quest_id = p_quest_id
    and assignment.member_id = v_member.id;

  if not found then
    raise exception 'Quest assignment not found';
  end if;

  return true;
end;
$$;

revoke all on function public.homequest_quest_is_available_for_member(
  uuid,
  uuid
) from public, anon, authenticated;
revoke all on function public.list_my_missions(uuid) from public, anon;
revoke all on function public.list_available_quests(uuid) from public, anon;
revoke all on function public.list_available_kingdom_quests(uuid)
from public, anon;
revoke all on function public.self_assign_quest(uuid) from public, anon;
revoke all on function public.leave_quest(uuid) from public, anon;

grant execute on function public.list_my_missions(uuid) to authenticated;
grant execute on function public.list_available_quests(uuid) to authenticated;
grant execute on function public.list_available_kingdom_quests(uuid)
to authenticated;
grant execute on function public.self_assign_quest(uuid) to authenticated;
grant execute on function public.leave_quest(uuid) to authenticated;

notify pgrst, 'reload schema';
