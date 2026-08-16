-- Prevent the legacy family/kingdom role synchronisation triggers from
-- recursively updating one another during onboarding.

create or replace function public.sync_family_member_legacy_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid := coalesce(new.member_id, old.member_id);
  v_family_role public.family_role;
  v_membership_scope public.membership_scope;
  v_domain_id uuid;
  v_expires_at timestamptz;
begin
  if v_member_id is null then
    return coalesce(new, old);
  end if;

  if exists (
    select 1
    from public.kingdom_members assignment
    where assignment.member_id = v_member_id
      and assignment.role = 'guardian'
      and assignment.is_active = true
      and (assignment.expires_at is null or assignment.expires_at > now())
  ) then
    v_family_role := 'guardian'::public.family_role;
    v_membership_scope := 'kingdom'::public.membership_scope;
    v_domain_id := null;
    v_expires_at := null;
  else
    select 'adventurer'::public.family_role, member.membership_scope, member.domain_id,
           member.expires_at
    into v_family_role, v_membership_scope, v_domain_id, v_expires_at
    from public.family_members member
    where member.id = v_member_id;
  end if;

  -- The previous implementation always issued an UPDATE. That UPDATE fired
  -- route_member_to_primary_kingdom(), which updated kingdom_members again,
  -- and its AFTER trigger called this function indefinitely.
  update public.family_members member
  set role = v_family_role,
      membership_scope = v_membership_scope,
      domain_id = v_domain_id,
      expires_at = v_expires_at
  where member.id = v_member_id
    and (
      member.role is distinct from v_family_role
      or member.membership_scope is distinct from v_membership_scope
      or member.domain_id is distinct from v_domain_id
      or member.expires_at is distinct from v_expires_at
    );

  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_family_member_legacy_role()
  from public, anon, authenticated;

notify pgrst, 'reload schema';
