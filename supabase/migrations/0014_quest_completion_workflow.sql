-- HomeQuest v0.5.0-alpha
-- Complete, review and reward quests atomically.

alter table public.quest_completions
  add column if not exists rejection_reason text,
  add column if not exists rewarded_at timestamptz;

create unique index if not exists quest_completions_one_pending_idx
  on public.quest_completions (quest_id, completed_by)
  where status = 'pending';

create table if not exists public.boss_damage_events (
  id uuid primary key default gen_random_uuid(),
  boss_id uuid not null references public.bosses(id) on delete cascade,
  completion_id uuid not null unique
    references public.quest_completions(id) on delete cascade,
  damage integer not null check (damage >= 0),
  created_at timestamptz not null default now()
);

alter table public.boss_damage_events enable row level security;

drop policy if exists "Members can read boss damage events"
on public.boss_damage_events;

create policy "Members can read boss damage events"
on public.boss_damage_events for select to authenticated
using (
  exists (
    select 1 from public.bosses b
    where b.id = boss_damage_events.boss_id
      and public.is_family_member(b.family_id)
  )
);

create or replace function public.homequest_level_for_xp(p_xp integer)
returns integer
language sql
immutable
as $$
  select case
    when p_xp < 100 then 1
    when p_xp < 250 then 2
    when p_xp < 450 then 3
    when p_xp < 700 then 4
    when p_xp < 1000 then 5
    when p_xp < 1350 then 6
    when p_xp < 1750 then 7
    when p_xp < 2200 then 8
    when p_xp < 2700 then 9
    else 10 + floor((p_xp - 2700) / 500.0)::integer
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

  select coalesce(jsonb_agg(row_data order by row_data->>'assigned_at' desc), '[]'::jsonb)
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
  ) missions;

  return v_result;
end;
$$;

create or replace function public.list_pending_quest_completions(
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
  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can review completions';
  end if;

  select coalesce(jsonb_agg(row_data order by row_data->>'completed_at'), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
      'id', qc.id,
      'quest_id', q.id,
      'quest_title', q.title,
      'real_task', q.real_task,
      'completed_by', qc.completed_by,
      'display_name', p.display_name,
      'note', qc.note,
      'photo_url', qc.photo_url,
      'completed_at', qc.completed_at,
      'xp_reward', q.xp_reward,
      'gold_reward', q.gold_reward,
      'boss_damage', q.boss_damage
    ) as row_data
    from public.quest_completions qc
    join public.quests q on q.id = qc.quest_id
    join public.family_members fm on fm.id = qc.completed_by
    join public.profiles p on p.id = fm.user_id
    where q.family_id = p_family_id
      and qc.status = 'pending'
  ) pending;

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
  select * into v_completion
  from public.quest_completions
  where id = p_completion_id
  for update;

  if v_completion.id is null then
    raise exception 'Completion not found';
  end if;
  if v_completion.status <> 'pending' then
    raise exception 'Completion has already been reviewed';
  end if;
  if not p_allow_self and v_completion.completed_by = p_reviewer_member_id then
    raise exception 'A guardian cannot approve their own quest';
  end if;

  select * into v_quest from public.quests where id = v_completion.quest_id;
  select * into v_member
  from public.family_members where id = v_completion.completed_by for update;
  select * into v_profile from public.profiles where id = v_member.user_id;

  v_new_xp := v_member.xp + v_quest.xp_reward;
  v_new_level := public.homequest_level_for_xp(v_new_xp);

  update public.family_members
  set xp = v_new_xp,
      gold = gold + v_quest.gold_reward,
      level = greatest(level, v_new_level)
  where id = v_member.id;

  insert into public.member_skills (member_id, skill_id, xp, level, updated_at)
  select v_member.id, qsr.skill_id, qsr.xp_reward,
         public.homequest_level_for_xp(qsr.xp_reward), now()
  from public.quest_skill_rewards qsr
  where qsr.quest_id = v_quest.id
  on conflict (member_id, skill_id) do update
  set xp = public.member_skills.xp + excluded.xp,
      level = public.homequest_level_for_xp(
        public.member_skills.xp + excluded.xp
      ),
      updated_at = now();

  select * into v_boss
  from public.bosses
  where family_id = v_quest.family_id
    and status = 'active'
    and (ends_at is null or ends_at > now())
  order by starts_at desc
  limit 1
  for update;

  if v_boss.id is not null then
    update public.bosses
    set current_hp = greatest(0, current_hp - v_quest.boss_damage),
        status = case
          when current_hp - v_quest.boss_damage <= 0
            then 'defeated'::boss_status
          else status
        end
    where id = v_boss.id;

    insert into public.boss_damage_events (boss_id, completion_id, damage)
    values (v_boss.id, v_completion.id, v_quest.boss_damage);

    v_boss_defeated := v_boss.current_hp - v_quest.boss_damage <= 0;
  end if;

  update public.quest_completions
  set status = 'approved',
      approved_by = p_reviewer_member_id,
      approved_at = now(),
      rewarded_at = now(),
      rejection_reason = null
  where id = v_completion.id;

  insert into public.chronicles (family_id, type, title, body)
  values (
    v_quest.family_id,
    'quest_completed',
    v_profile.display_name || ' a accompli « ' || v_quest.title || ' »',
    '+' || v_quest.xp_reward || ' XP, +' || v_quest.gold_reward ||
      ' or et ' || v_quest.boss_damage || ' dégâts au boss.'
  );

  return jsonb_build_object(
    'completion_id', v_completion.id,
    'xp_reward', v_quest.xp_reward,
    'gold_reward', v_quest.gold_reward,
    'boss_damage', case when v_boss.id is null then 0 else v_quest.boss_damage end,
    'new_xp', v_new_xp,
    'new_level', greatest(v_member.level, v_new_level),
    'boss_defeated', v_boss_defeated
  );
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
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_quest from public.quests where id = p_quest_id;
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

  if v_member.id is null then raise exception 'Active membership required'; end if;
  if not exists (
    select 1 from public.quest_assignments
    where quest_id = v_quest.id and member_id = v_member.id
  ) then
    raise exception 'Quest must be assigned before completion';
  end if;
  if exists (
    select 1 from public.quest_completions
    where quest_id = v_quest.id
      and completed_by = v_member.id
      and status = 'pending'
  ) then
    raise exception 'Quest is already waiting for approval';
  end if;
  if v_quest.frequency = 'once' and exists (
    select 1 from public.quest_completions
    where quest_id = v_quest.id
      and completed_by = v_member.id
      and status = 'approved'
  ) then
    raise exception 'One-time quest has already been completed';
  end if;
  if v_quest.frequency = 'daily' and exists (
    select 1 from public.quest_completions
    where quest_id = v_quest.id
      and completed_by = v_member.id
      and status = 'approved'
      and completed_at::date = current_date
  ) then
    raise exception 'Daily quest has already been completed today';
  end if;
  if v_quest.frequency = 'weekly' and exists (
    select 1 from public.quest_completions
    where quest_id = v_quest.id
      and completed_by = v_member.id
      and status = 'approved'
      and date_trunc('week', completed_at) = date_trunc('week', now())
  ) then
    raise exception 'Weekly quest has already been completed this week';
  end if;

  insert into public.quest_completions (
    quest_id, completed_by, status, note, photo_url
  ) values (
    v_quest.id, v_member.id, 'pending', nullif(trim(p_note), ''), p_photo_url
  ) returning * into v_completion;

  if not v_quest.requires_approval then
    v_reward := public.apply_quest_completion_rewards(
      v_completion.id, v_member.id, true
    );
  end if;

  return jsonb_build_object(
    'completion', to_jsonb(v_completion),
    'auto_approved', not v_quest.requires_approval,
    'reward', v_reward
  );
end;
$$;

create or replace function public.review_quest_completion(
  p_completion_id uuid,
  p_approve boolean,
  p_rejection_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_completion public.quest_completions;
  v_quest public.quests;
  v_reviewer public.family_members;
begin
  select * into v_completion
  from public.quest_completions where id = p_completion_id for update;
  if v_completion.id is null then raise exception 'Completion not found'; end if;

  select * into v_quest from public.quests where id = v_completion.quest_id;
  select * into v_reviewer
  from public.family_members
  where family_id = v_quest.family_id
    and user_id = auth.uid()
    and role = 'guardian'
    and is_active = true
    and (expires_at is null or expires_at > now())
  limit 1;

  if v_reviewer.id is null then
    raise exception 'Only active guardians can review completions';
  end if;
  if v_completion.status <> 'pending' then
    raise exception 'Completion has already been reviewed';
  end if;

  if p_approve then
    return public.apply_quest_completion_rewards(
      v_completion.id, v_reviewer.id, false
    );
  end if;

  if nullif(trim(p_rejection_reason), '') is null then
    raise exception 'A rejection reason is required';
  end if;

  update public.quest_completions
  set status = 'rejected',
      rejection_reason = trim(p_rejection_reason),
      approved_by = v_reviewer.id,
      approved_at = now()
  where id = v_completion.id;

  return jsonb_build_object(
    'completion_id', v_completion.id,
    'status', 'rejected'
  );
end;
$$;

revoke all on function public.homequest_level_for_xp(integer) from public;
revoke all on function public.apply_quest_completion_rewards(uuid, uuid, boolean) from public;
revoke all on function public.list_my_missions(uuid) from public;
revoke all on function public.list_pending_quest_completions(uuid) from public;
revoke all on function public.submit_quest_completion(uuid, text, text) from public;
revoke all on function public.review_quest_completion(uuid, boolean, text) from public;

grant execute on function public.list_my_missions(uuid) to authenticated;
grant execute on function public.list_pending_quest_completions(uuid) to authenticated;
grant execute on function public.submit_quest_completion(uuid, text, text) to authenticated;
grant execute on function public.review_quest_completion(uuid, boolean, text) to authenticated;

notify pgrst, 'reload schema';
