-- Align recurring quests with their intended cadence:
-- - daily quests reopen at their configured local hour every day;
-- - weekly quests reopen seven days after the member's latest completion.

create or replace function public.homequest_next_daily_occurrence(
  p_anchor timestamptz,
  p_after timestamptz
)
returns timestamptz
language sql
stable
set search_path = public
as $$
  with local_times as (
    select
      p_anchor at time zone 'Europe/Paris' as anchor_local,
      p_after at time zone 'Europe/Paris' as after_local
  ),
  candidate as (
    select
      anchor_local,
      after_local,
      after_local::date + anchor_local::time as candidate_local
    from local_times
  )
  select case
    when p_anchor is null or p_after is null then null
    when p_after < p_anchor then p_anchor
    when candidate_local <= after_local
      then (candidate_local + interval '1 day')
        at time zone 'Europe/Paris'
    else candidate_local at time zone 'Europe/Paris'
  end
  from candidate;
$$;

create or replace function public.homequest_quest_next_available_at(
  p_quest_id uuid,
  p_member_id uuid
)
returns timestamptz
language sql
stable
set search_path = public
as $$
  with quest_state as (
    select
      q.frequency,
      case
        when q.frequency = 'daily' then coalesce(
          q.available_from,
          (
            (q.created_at at time zone 'Europe/Paris')::date::timestamp
            at time zone 'Europe/Paris'
          )
        )
        else coalesce(q.available_from, q.created_at)
      end as first_available_at,
      max(qc.completed_at) filter (
        where qc.status = 'approved'
      ) as last_completed_at,
      bool_or(qc.status = 'pending') as has_pending
    from public.quests q
    left join public.quest_completions qc
      on qc.quest_id = q.id
     and qc.completed_by = p_member_id
    where q.id = p_quest_id
      and q.status = 'active'
    group by q.id
  )
  select case
    when coalesce(has_pending, false) then null
    when last_completed_at is null then first_available_at
    when frequency = 'daily' then
      public.homequest_next_daily_occurrence(
        first_available_at,
        last_completed_at
      )
    when frequency = 'weekly' then last_completed_at + interval '7 days'
    else null
  end
  from quest_state;
$$;

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
          and qc.completed_by = p_member_id
          and qc.status = 'pending'
      )
      and (
        (
          q.frequency = 'once'
          and coalesce(q.available_from, q.created_at) <= now()
          and not exists (
            select 1
            from public.quest_completions qc
            where qc.quest_id = q.id
              and qc.status in ('pending', 'approved')
          )
        )
        or (
          q.frequency in ('daily', 'weekly')
          and public.homequest_quest_next_available_at(
            q.id,
            p_member_id
          ) <= now()
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
      'next_available_at',
        public.homequest_quest_next_available_at(q.id, v_member.id),
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

create or replace function public.submit_quest_completion(
  p_quest_id uuid,
  p_note text default null,
  p_photo_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quest public.quests;
  v_member public.family_members;
  v_completion public.quest_completions;
  v_reward jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_quest
  from public.quests
  where id = p_quest_id;

  if v_quest.id is null or v_quest.status <> 'active' then
    raise exception 'Active quest not found';
  end if;

  select * into v_member
  from public.family_members
  where family_id = v_quest.family_id
    and user_id = auth.uid()
    and is_active = true
    and (expires_at is null or expires_at > now())
  limit 1;

  if v_member.id is null then
    raise exception 'Active membership required';
  end if;

  if not exists (
    select 1
    from public.quest_assignments
    where quest_id = v_quest.id
      and member_id = v_member.id
  ) then
    raise exception 'Quest must be assigned before completion';
  end if;

  if not public.homequest_quest_is_available_for_member(
    v_quest.id,
    v_member.id
  ) then
    if exists (
      select 1
      from public.quest_completions
      where quest_id = v_quest.id
        and completed_by = v_member.id
        and status = 'pending'
    ) then
      raise exception 'Quest is already waiting for approval';
    end if;

    if v_quest.frequency = 'once' then
      raise exception 'One-time quest has already been completed';
    end if;

    raise exception 'Recurring quest is not available yet';
  end if;

  insert into public.quest_completions (
    quest_id,
    completed_by,
    status,
    note,
    photo_url
  )
  values (
    v_quest.id,
    v_member.id,
    'pending',
    nullif(trim(p_note), ''),
    p_photo_url
  )
  returning * into v_completion;

  if not v_quest.requires_approval then
    v_reward := public.apply_quest_completion_rewards(
      v_completion.id,
      v_member.id,
      true
    );
  end if;

  return jsonb_build_object(
    'completion', to_jsonb(v_completion),
    'auto_approved', not v_quest.requires_approval,
    'reward', v_reward
  );
end;
$$;

revoke all on function public.homequest_next_daily_occurrence(
  timestamptz,
  timestamptz
) from public, anon, authenticated;
revoke all on function public.homequest_quest_next_available_at(
  uuid,
  uuid
) from public, anon, authenticated;
revoke all on function public.homequest_quest_is_available_for_member(
  uuid,
  uuid
) from public, anon, authenticated;
revoke all on function public.list_my_missions(uuid) from public, anon;
revoke all on function public.submit_quest_completion(
  uuid,
  text,
  text
) from public, anon;

grant execute on function public.list_my_missions(uuid) to authenticated;
grant execute on function public.submit_quest_completion(
  uuid,
  text,
  text
) to authenticated;

notify pgrst, 'reload schema';
