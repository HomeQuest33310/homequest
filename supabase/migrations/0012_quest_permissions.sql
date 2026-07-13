-- HomeQuest v0.4.1-alpha
-- Autoassignation des quêtes selon le rôle et le périmètre.

create or replace function public.self_assign_quest(
  p_quest_id uuid
)
returns public.quest_assignments
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_quest public.quests;
  current_member public.family_members;
  created_assignment public.quest_assignments;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into target_quest
  from public.quests
  where id = p_quest_id;

  if target_quest.id is null then
    raise exception 'Quest not found';
  end if;

  if target_quest.status <> 'active' then
    raise exception 'Only active quests can be self-assigned';
  end if;

  select *
  into current_member
  from public.family_members
  where family_id = target_quest.family_id
    and user_id = auth.uid()
    and is_active = true
    and (
      expires_at is null
      or expires_at > now()
    )
  limit 1;

  if current_member.id is null then
    raise exception 'You are not an active member of this kingdom';
  end if;

  if current_member.role not in ('guardian', 'adventurer', 'mercenary') then
    raise exception 'This role cannot self-assign quests';
  end if;

  -- Un mercenaire limité à un Domaine ne peut prendre
  -- que les quêtes de ce Domaine.
  if current_member.role = 'mercenary'
     and current_member.membership_scope = 'domain' then
    if current_member.domain_id is null then
      raise exception 'Mercenary domain scope is invalid';
    end if;

    if target_quest.domain_id is distinct from current_member.domain_id then
      raise exception 'This quest is outside your assigned domain';
    end if;
  end if;

  insert into public.quest_assignments (
    quest_id,
    member_id
  )
  values (
    target_quest.id,
    current_member.id
  )
  on conflict (quest_id, member_id)
  do update set
    assigned_at = now()
  returning *
  into created_assignment;

  return created_assignment;
end;
$$;

revoke all on function public.self_assign_quest(uuid) from public;

grant execute on function public.self_assign_quest(uuid)
to authenticated;

notify pgrst, 'reload schema';