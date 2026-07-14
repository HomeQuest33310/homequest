-- Let Guardians confirm that an unlocked collective reward was delivered.

alter table public.reward_suggestions
  add column if not exists delivered_at timestamptz,
  add column if not exists delivered_by uuid
    references public.family_members(id) on delete set null;

create index if not exists reward_suggestions_delivered_by_idx
  on public.reward_suggestions(delivered_by)
  where delivered_by is not null;

create or replace function public.deliver_collective_reward(
  p_suggestion_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  suggestion public.reward_suggestions%rowtype;
  guardian_member_id uuid;
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into suggestion
  from public.reward_suggestions
  where id = p_suggestion_id
  for update;

  if suggestion.id is null then
    raise exception 'Collective reward not found';
  end if;

  if not public.is_family_guardian(suggestion.family_id) then
    raise exception 'Only guardians can deliver collective rewards';
  end if;

  if suggestion.status <> 'approved' or suggestion.fulfilled_at is null then
    raise exception 'The collective reward is not unlocked yet';
  end if;

  if suggestion.delivered_at is not null then
    raise exception 'The collective reward has already been delivered';
  end if;

  select member.id
  into guardian_member_id
  from public.family_members member
  where member.family_id = suggestion.family_id
    and member.user_id = auth.uid()
    and member.role = 'guardian'
    and member.is_active
    and (member.expires_at is null or member.expires_at > now())
  limit 1;

  if guardian_member_id is null then
    raise exception 'Active guardian membership required';
  end if;

  update public.reward_suggestions
  set delivered_at = now(),
      delivered_by = guardian_member_id,
      updated_at = now()
  where id = suggestion.id
  returning to_jsonb(reward_suggestions.*)
  into result;

  insert into public.chronicles (family_id, type, title, body)
  values (
    suggestion.family_id,
    'reward_claimed',
    'Une récompense collective a été remise',
    'Le Royaume reçoit « ' ||
      coalesce(nullif(trim(suggestion.guardian_title), ''), suggestion.title) ||
      ' ». Tous les héros peuvent célébrer leur réussite.'
  );

  return result;
end;
$$;

revoke all on function public.deliver_collective_reward(uuid)
  from public, anon;
grant execute on function public.deliver_collective_reward(uuid)
  to authenticated;

comment on function public.deliver_collective_reward(uuid) is
  'Allows an active Guardian to confirm delivery of an unlocked collective reward.';

notify pgrst, 'reload schema';
