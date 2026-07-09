-- HomeQuest v0.3.4-alpha
-- Assign quest RPC

create or replace function public.assign_quest(
  p_quest_id uuid,
  p_member_id uuid
)
returns quest_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_id uuid;
  assigned quest_assignments;
begin
  select family_id
  into target_family_id
  from quests
  where id = p_quest_id;

  if target_family_id is null then
    raise exception 'Quest not found';
  end if;

  if not is_family_guardian(target_family_id) then
    raise exception 'Only guardians can assign quests';
  end if;

  insert into quest_assignments (
    quest_id,
    member_id
  )
  values (
    p_quest_id,
    p_member_id
  )
  on conflict (quest_id, member_id) do update
  set assigned_at = now()
  returning * into assigned;

  return assigned;
end;
$$;