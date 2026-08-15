-- Use the scheduled hour for daily quests and a fixed weekday/hour for weekly quests.

create or replace function public.homequest_next_weekly_occurrence(
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
  ), candidates as (
    select
      anchor_local,
      after_local,
      (
        after_local::date
        + ((extract(isodow from anchor_local)::int
            - extract(isodow from after_local)::int + 7) % 7)
        + anchor_local::time
      ) as candidate_local
    from local_times
  )
  select case
    when p_anchor is null or p_after is null then null
    when p_after < p_anchor then p_anchor
    when candidate_local <= after_local
      then (candidate_local + interval '7 days') at time zone 'Europe/Paris'
    else candidate_local at time zone 'Europe/Paris'
  end
  from candidates;
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
      coalesce(q.available_from, q.created_at) as first_available_at,
      max(qc.completed_at) filter (where qc.status = 'approved')
        as last_completed_at,
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
    when frequency = 'daily' then public.homequest_next_daily_occurrence(
      first_available_at, last_completed_at)
    when frequency = 'weekly' then public.homequest_next_weekly_occurrence(
      first_available_at, last_completed_at)
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
  select public.homequest_quest_next_available_at(p_quest_id, p_member_id) <= now()
    and not exists (
      select 1 from public.quest_completions qc
      where qc.quest_id = p_quest_id
        and qc.completed_by = p_member_id
        and qc.status = 'pending'
    );
$$;

revoke all on function public.homequest_next_weekly_occurrence(timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function public.homequest_next_weekly_occurrence(timestamptz, timestamptz)
  to authenticated;

notify pgrst, 'reload schema';
