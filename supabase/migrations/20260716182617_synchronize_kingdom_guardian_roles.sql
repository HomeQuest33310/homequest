-- Keep the legacy family role and the role of the selected kingdom aligned.
-- A role change must target one kingdom because the same person may have a
-- different role in another home.

create or replace function public.change_kingdom_member_role(
  p_member_id uuid,
  p_kingdom_id uuid,
  p_new_role public.family_role
)
returns public.family_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member public.family_members%rowtype;
  v_assignment public.kingdom_members%rowtype;
  v_owner_id uuid;
  v_active_guardian_count integer;
  v_family_role public.family_role;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_new_role not in ('guardian', 'adventurer', 'mercenary') then
    raise exception 'Unsupported role';
  end if;

  select member.*
  into v_member
  from public.family_members member
  where member.id = p_member_id
  for update;

  if v_member.id is null then
    raise exception 'Family member not found';
  end if;

  select assignment.*
  into v_assignment
  from public.kingdom_members assignment
  join public.kingdoms kingdom on kingdom.id = assignment.kingdom_id
  where assignment.member_id = p_member_id
    and assignment.kingdom_id = p_kingdom_id
    and kingdom.family_id = v_member.family_id
    and kingdom.archived_at is null
  for update of assignment;

  if v_assignment.id is null then
    raise exception 'Kingdom membership not found';
  end if;
  if not public.is_kingdom_guardian(p_kingdom_id) then
    raise exception 'Only this kingdom''s guardians can change member roles';
  end if;

  select family.owner_id
  into v_owner_id
  from public.families family
  where family.id = v_member.family_id;

  if v_member.user_id = v_owner_id and p_new_role <> 'guardian' then
    raise exception 'The kingdom owner must remain a guardian';
  end if;

  if v_assignment.role = 'guardian' and p_new_role <> 'guardian' then
    select count(*)
    into v_active_guardian_count
    from public.kingdom_members assignment
    where assignment.kingdom_id = p_kingdom_id
      and assignment.role = 'guardian'
      and assignment.is_active
      and (
        assignment.expires_at is null
        or assignment.expires_at > now()
      );

    if v_active_guardian_count <= 1 then
      raise exception 'The kingdom must keep at least one active guardian';
    end if;
  end if;

  update public.kingdom_members
  set role = p_new_role,
      membership_scope = case
        when p_new_role in ('guardian', 'adventurer')
          then 'kingdom'::public.membership_scope
        else membership_scope
      end,
      domain_id = case
        when p_new_role in ('guardian', 'adventurer') then null
        else domain_id
      end,
      expires_at = case
        when p_new_role <> 'mercenary' then null
        else expires_at
      end
  where id = v_assignment.id;

  select case
    when exists (
      select 1
      from public.kingdom_members assignment
      where assignment.member_id = p_member_id
        and assignment.role = 'guardian'
        and assignment.is_active
        and (
          assignment.expires_at is null
          or assignment.expires_at > now()
        )
    ) then 'guardian'::public.family_role
    else p_new_role
  end
  into v_family_role;

  update public.family_members
  set role = v_family_role,
      membership_scope = case
        when v_family_role in ('guardian', 'adventurer')
          then 'kingdom'::public.membership_scope
        else membership_scope
      end,
      domain_id = case
        when v_family_role in ('guardian', 'adventurer') then null
        else domain_id
      end,
      expires_at = case
        when v_family_role <> 'mercenary' then null
        else expires_at
      end
  where id = p_member_id
  returning * into v_member;

  return v_member;
end;
$$;

revoke execute on function public.change_family_member_role(
  uuid, public.family_role
) from public, anon, authenticated;
revoke execute on function public.change_kingdom_member_role(
  uuid, uuid, public.family_role
) from public, anon;
grant execute on function public.change_kingdom_member_role(
  uuid, uuid, public.family_role
) to authenticated;

-- Repair the member whose promotion exposed this synchronization bug.
update public.kingdom_members assignment
set role = 'guardian'::public.family_role,
    membership_scope = 'kingdom'::public.membership_scope,
    domain_id = null,
    expires_at = null
from public.kingdoms kingdom
where assignment.kingdom_id = kingdom.id
  and assignment.member_id = 'e00a261f-2633-4eb9-a1b8-b8a79ec26e1a'::uuid
  and kingdom.name = 'PeMaChaMer'
  and assignment.role = 'adventurer';

notify pgrst, 'reload schema';
