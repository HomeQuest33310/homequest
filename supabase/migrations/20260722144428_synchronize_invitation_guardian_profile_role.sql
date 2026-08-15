-- Keep the legacy family_members.role compatible with kingdom-scoped roles.
-- The selected kingdom remains authoritative in the client, while this
-- fallback keeps older family-scoped RPCs and profile screens consistent.

create or replace function public.sync_family_member_legacy_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid := coalesce(new.member_id, old.member_id);
begin
  update public.family_members member
  set role = case
    when exists (
      select 1
      from public.kingdom_members assignment
      where assignment.member_id = v_member_id
        and assignment.role = 'guardian'
        and assignment.is_active = true
        and (assignment.expires_at is null or assignment.expires_at > now())
    )
    or exists (
      select 1
      from public.families family
      where family.id = member.family_id
        and family.owner_id = member.user_id
    ) then 'guardian'::public.family_role
    else 'adventurer'::public.family_role
  end,
  membership_scope = case
    when exists (
      select 1
      from public.kingdom_members assignment
      where assignment.member_id = v_member_id
        and assignment.role = 'guardian'
        and assignment.is_active = true
        and (assignment.expires_at is null or assignment.expires_at > now())
    ) then 'kingdom'::public.membership_scope
    else member.membership_scope
  end,
  domain_id = case
    when exists (
      select 1
      from public.kingdom_members assignment
      where assignment.member_id = v_member_id
        and assignment.role = 'guardian'
        and assignment.is_active = true
        and (assignment.expires_at is null or assignment.expires_at > now())
    ) then null
    else member.domain_id
  end
  where member.id = v_member_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists sync_family_member_legacy_role_on_kingdom_members
on public.kingdom_members;
create trigger sync_family_member_legacy_role_on_kingdom_members
after insert or update or delete on public.kingdom_members
for each row execute function public.sync_family_member_legacy_role();

-- Repair the reported account and any other family membership that already
-- has an active guardian assignment.
update public.family_members member
set role = 'guardian'::public.family_role,
    membership_scope = 'kingdom'::public.membership_scope,
    domain_id = null
where member.user_id = '75387243-99b3-4e7d-8c91-0100321f38a5'::uuid
  and exists (
    select 1
    from public.kingdom_members assignment
    where assignment.member_id = member.id
      and assignment.role = 'guardian'
      and assignment.is_active = true
      and (assignment.expires_at is null or assignment.expires_at > now())
  );

notify pgrst, 'reload schema';
