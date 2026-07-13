-- HomeQuest v0.5.1-alpha
-- A guardian may approve their own completion when they are the only guardian.
-- Idempotency remains enforced by the locked completion status and rewarded_at.

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
  from public.quest_completions
  where id = p_completion_id
  for update;

  if v_completion.id is null then
    raise exception 'Completion not found';
  end if;

  select * into v_quest
  from public.quests
  where id = v_completion.quest_id;

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
    -- Self-approval is intentionally allowed for single-guardian families.
    return public.apply_quest_completion_rewards(
      v_completion.id,
      v_reviewer.id,
      true
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

revoke all on function public.review_quest_completion(uuid, boolean, text)
from public;

grant execute on function public.review_quest_completion(uuid, boolean, text)
to authenticated;

notify pgrst, 'reload schema';
