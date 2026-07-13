-- HomeQuest v0.5.3-alpha
-- Hide completed quests from availability and notify guardians when a member
-- joins a quest that was already assigned to somebody else.

create table if not exists public.guardian_notifications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  recipient_member_id uuid not null
    references public.family_members(id) on delete cascade,
  actor_member_id uuid
    references public.family_members(id) on delete set null,
  quest_id uuid references public.quests(id) on delete cascade,
  kind text not null check (kind in ('quest_joined')),
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists guardian_notifications_assignment_idx
  on public.guardian_notifications (
    recipient_member_id,
    quest_id,
    actor_member_id,
    kind
  );

create index if not exists guardian_notifications_recipient_created_idx
  on public.guardian_notifications (recipient_member_id, created_at desc);

alter table public.guardian_notifications enable row level security;

drop policy if exists "Guardians can read their notifications"
on public.guardian_notifications;

create policy "Guardians can read their notifications"
on public.guardian_notifications for select to authenticated
using (
  exists (
    select 1
    from public.family_members fm
    where fm.id = guardian_notifications.recipient_member_id
      and fm.user_id = (select auth.uid())
      and fm.role = 'guardian'
      and fm.is_active = true
      and (fm.expires_at is null or fm.expires_at > now())
  )
);

grant select on public.guardian_notifications to authenticated;

create or replace function public.homequest_quest_is_available(
  p_quest_id uuid
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
            qc.status = 'pending'
            or (
              qc.status = 'approved'
              and (
                q.frequency = 'once'
                or (
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
  );
$$;

create or replace function public.list_available_quests(
  p_family_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_family_member(p_family_id) then
    raise exception 'Active family membership required';
  end if;

  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc), '[]'::jsonb)
  into v_result
  from public.quests q
  where q.family_id = p_family_id
    and public.homequest_quest_is_available(q.id);

  return v_result;
end;
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
        public.homequest_quest_is_available(q.id)
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

create or replace function public.list_my_guardian_notifications(
  p_family_id uuid
)
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
    and role = 'guardian'
    and is_active = true
    and (expires_at is null or expires_at > now())
  limit 1;

  if v_member.id is null then
    raise exception 'Only active guardians can read notifications';
  end if;

  select coalesce(
    jsonb_agg(to_jsonb(n) order by n.created_at desc),
    '[]'::jsonb
  )
  into v_result
  from (
    select *
    from public.guardian_notifications
    where family_id = p_family_id
      and recipient_member_id = v_member.id
    order by created_at desc
    limit 100
  ) n;

  return v_result;
end;
$$;

create or replace function public.mark_guardian_notification_read(
  p_notification_id uuid
)
returns public.guardian_notifications
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_notification public.guardian_notifications;
begin
  update public.guardian_notifications n
  set read_at = coalesce(n.read_at, now())
  where n.id = p_notification_id
    and exists (
      select 1
      from public.family_members fm
      where fm.id = n.recipient_member_id
        and fm.user_id = auth.uid()
        and fm.role = 'guardian'
        and fm.is_active = true
        and (fm.expires_at is null or fm.expires_at > now())
    )
  returning * into v_notification;

  if v_notification.id is null then
    raise exception 'Notification not found';
  end if;

  return v_notification;
end;
$$;

revoke all on function public.homequest_quest_is_available(uuid) from public;
revoke all on function public.list_available_quests(uuid) from public;
revoke all on function public.list_my_missions(uuid) from public;
revoke all on function public.self_assign_quest(uuid) from public;
revoke all on function public.list_my_guardian_notifications(uuid) from public;
revoke all on function public.mark_guardian_notification_read(uuid) from public;

grant execute on function public.list_available_quests(uuid) to authenticated;
grant execute on function public.list_my_missions(uuid) to authenticated;
grant execute on function public.self_assign_quest(uuid) to authenticated;
grant execute on function public.list_my_guardian_notifications(uuid)
to authenticated;
grant execute on function public.mark_guardian_notification_read(uuid)
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'guardian_notifications'
  ) then
    alter publication supabase_realtime
      add table public.guardian_notifications;
  end if;
end;
$$;

notify pgrst, 'reload schema';
