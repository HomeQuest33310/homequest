-- One-time quests are completed globally after approval. Guardians can include
-- other assigned members and split the quest rewards equally between them.

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
      'frequency', q.frequency,
      'completed_by', qc.completed_by,
      'display_name', p.display_name,
      'note', qc.note,
      'photo_url', qc.photo_url,
      'completed_at', qc.completed_at,
      'xp_reward', q.xp_reward,
      'gold_reward', q.gold_reward,
      'boss_damage', q.boss_damage,
      'assigned_members', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'member_id', assigned.id,
          'display_name', assigned_profile.display_name
        ) order by assigned_profile.display_name), '[]'::jsonb)
        from public.quest_assignments assignment
        join public.family_members assigned
          on assigned.id = assignment.member_id
        join public.profiles assigned_profile
          on assigned_profile.id = assigned.user_id
        where assignment.quest_id = q.id
          and assigned.is_active = true
      )
    ) as row_data
    from public.quest_completions qc
    join public.quests q on q.id = qc.quest_id
    join public.family_members fm on fm.id = qc.completed_by
    join public.profiles p on p.id = fm.user_id
    where q.family_id = p_family_id
      and q.status = 'active'
      and qc.status = 'pending'
  ) pending;

  return v_result;
end;
$$;

-- Keep the legacy approval RPC safe for older clients: an approved one-time
-- quest is archived immediately and cannot be approved a second time.
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
  v_result jsonb;
begin
  select * into v_completion
  from public.quest_completions
  where id = p_completion_id
  for update;
  if v_completion.id is null then raise exception 'Completion not found'; end if;

  select * into v_quest from public.quests where id = v_completion.quest_id;
  if v_quest.status = 'archived' then
    raise exception 'This quest has already been completed and archived';
  end if;

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
    v_result := public.apply_quest_completion_rewards(
      v_completion.id, v_reviewer.id, false
    );
    if v_quest.frequency = 'once' then
      update public.quests
      set status = 'archived'
      where id = v_quest.id and status = 'active';
    end if;
    return v_result;
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

create or replace function public.review_quest_completion_with_participants(
  p_completion_id uuid,
  p_approve boolean,
  p_rejection_reason text default null,
  p_participant_ids jsonb default '[]'::jsonb
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
  v_participant_ids uuid[];
  v_participant_id uuid;
  v_participant_count integer;
  v_ordinal integer;
  v_share integer;
  v_remainder integer;
  v_gold_share integer;
  v_result jsonb;
  v_skill record;
begin
  select * into v_completion
  from public.quest_completions
  where id = p_completion_id
  for update;
  if v_completion.id is null then raise exception 'Completion not found'; end if;

  select * into v_quest from public.quests where id = v_completion.quest_id;
  if v_quest.status = 'archived' then
    raise exception 'This quest has already been completed and archived';
  end if;

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

  -- Rejections and recurring quests retain the existing workflow.
  if not p_approve or v_quest.frequency <> 'once' then
    return public.review_quest_completion(
      p_completion_id, p_approve, p_rejection_reason
    );
  end if;

  select array_agg(participant_id order by participant_id)
  into v_participant_ids
  from (
    select distinct value::uuid as participant_id
    from jsonb_array_elements_text(coalesce(p_participant_ids, '[]'::jsonb))
  ) selected;
  v_participant_ids := coalesce(v_participant_ids, ARRAY[]::uuid[]);

  if not (v_completion.completed_by = any(v_participant_ids)) then
    v_participant_ids := array_append(v_participant_ids, v_completion.completed_by);
  end if;
  v_participant_count := cardinality(v_participant_ids);

  if exists (
    select 1
    from unnest(v_participant_ids) selected(member_id)
    where not exists (
      select 1
      from public.quest_assignments assignment
      join public.family_members member on member.id = assignment.member_id
      where assignment.quest_id = v_quest.id
        and assignment.member_id = selected.member_id
        and member.is_active = true
    )
  ) then
    raise exception 'Every participant must be an active assigned member';
  end if;

  -- The existing reward function handles validation, skills, boss damage and
  -- the completion row. It initially grants the full quest reward to the
  -- completing member; the adjustments below turn it into an equal split.
  v_result := public.review_quest_completion(
    p_completion_id, true, null
  );

  -- If several members submitted the same one-time quest before the first
  -- validation, close the other pending submissions instead of leaving them
  -- orphaned after the quest is archived.
  update public.quest_completions
  set status = 'rejected',
      rejection_reason = 'Quête déjà réalisée par un autre membre',
      approved_by = v_reviewer.id,
      approved_at = now()
  where quest_id = v_quest.id
    and id <> v_completion.id
    and status = 'pending';

  v_share := v_quest.xp_reward / v_participant_count;
  v_remainder := mod(v_quest.xp_reward, v_participant_count);
  v_ordinal := 0;
  foreach v_participant_id in array v_participant_ids loop
    v_ordinal := v_ordinal + 1;
    v_share := (v_quest.xp_reward / v_participant_count)
      + case when v_ordinal <= mod(v_quest.xp_reward, v_participant_count)
        then 1 else 0 end;
    if v_participant_id = v_completion.completed_by then
      update public.family_members
      set xp = greatest(0, xp - (v_quest.xp_reward - v_share)),
          gold = greatest(0, gold - (v_quest.gold_reward - (
            v_quest.gold_reward / v_participant_count
            + case when v_ordinal <= mod(v_quest.gold_reward, v_participant_count)
              then 1 else 0 end)))
      where id = v_participant_id;
    else
      update public.family_members
      set xp = xp + v_share,
          gold = gold + (v_quest.gold_reward / v_participant_count
            + case when v_ordinal <= mod(v_quest.gold_reward, v_participant_count)
              then 1 else 0 end)
      where id = v_participant_id;
    end if;
  end loop;

  for v_skill in
    select skill_id, xp_reward
    from public.quest_skill_rewards
    where quest_id = v_quest.id
  loop
    v_ordinal := 0;
    foreach v_participant_id in array v_participant_ids loop
      v_ordinal := v_ordinal + 1;
      v_share := (v_skill.xp_reward / v_participant_count)
        + case when v_ordinal <= mod(v_skill.xp_reward, v_participant_count)
          then 1 else 0 end;
      if v_participant_id = v_completion.completed_by then
        update public.member_skills
        set xp = greatest(0, xp - (v_skill.xp_reward - v_share)),
            level = public.homequest_skill_level_for_xp(
              greatest(0, xp - (v_skill.xp_reward - v_share)))
        where member_id = v_participant_id
          and skill_id = v_skill.skill_id;
      else
        insert into public.member_skills (member_id, skill_id, xp, level, updated_at)
        values (
          v_participant_id,
          v_skill.skill_id,
          v_share,
          public.homequest_skill_level_for_xp(v_share),
          now()
        )
        on conflict (member_id, skill_id) do update
        set xp = public.member_skills.xp + excluded.xp,
            level = public.homequest_skill_level_for_xp(
              public.member_skills.xp + excluded.xp),
            updated_at = now();
      end if;
    end loop;
  end loop;

  update public.family_members member
  set level = greatest(member.level, public.homequest_level_for_xp(member.xp))
  where member.id = any(v_participant_ids);

  update public.quests
  set status = 'archived'
  where id = v_quest.id and status = 'active';

  -- Publish the actual personal gains to every selected participant. The
  -- completion trigger already created a notification for the submitter;
  -- replace its full-reward text with the split amount and add the others.
  v_ordinal := 0;
  foreach v_participant_id in array v_participant_ids loop
    v_ordinal := v_ordinal + 1;
    v_share := (v_quest.xp_reward / v_participant_count)
      + case when v_ordinal <= mod(v_quest.xp_reward, v_participant_count)
        then 1 else 0 end;
    v_gold_share := (v_quest.gold_reward / v_participant_count)
      + case when v_ordinal <= mod(v_quest.gold_reward, v_participant_count)
        then 1 else 0 end;
    if v_participant_id = v_completion.completed_by then
      update public.guardian_notifications notification
      set body = 'Votre mission « ' || v_quest.title ||
        ' » a été validée. Gains personnels : +' || v_share ||
        ' XP, +' || v_gold_share || ' or et +' || v_quest.boss_damage ||
        ' dégâts au boss.'
      where notification.id = (
        select candidate.id
        from public.guardian_notifications candidate
        where candidate.recipient_member_id = v_participant_id
          and candidate.quest_id = v_quest.id
          and candidate.kind = 'completion_approved'
        order by candidate.created_at desc
        limit 1
      );
    else
      insert into public.guardian_notifications (
        family_id, recipient_member_id, quest_id, kind, title, body
      ) values (
        v_quest.family_id,
        v_participant_id,
        v_quest.id,
        'completion_approved',
        'Mission validée',
        'La mission « ' || v_quest.title ||
          ' » a été validée avec votre participation. Gains personnels : +'
          || v_share || ' XP et +' || v_gold_share || ' or.'
      );
    end if;
  end loop;

  return v_result || jsonb_build_object(
    'participants_count', v_participant_count,
    'quest_archived', true
  );
end;
$$;

revoke all on function public.review_quest_completion_with_participants(uuid, boolean, text, jsonb)
from public, anon;
grant execute on function public.review_quest_completion_with_participants(uuid, boolean, text, jsonb)
to authenticated;

notify pgrst, 'reload schema';
