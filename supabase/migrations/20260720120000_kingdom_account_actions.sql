-- Account-level kingdom actions.
-- A member may leave a kingdom they do not own. Their membership and access
-- are removed, while the kingdom and its history remain intact.

create or replace function public.leave_kingdom(p_kingdom_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_membership public.kingdom_members%rowtype;
  v_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select kingdom_member.*
  into v_membership
  from public.kingdom_members kingdom_member
  join public.family_members member on member.id = kingdom_member.member_id
  where kingdom_member.kingdom_id = p_kingdom_id
    and member.user_id = auth.uid()
    and kingdom_member.is_active = true
  for update;

  if not found then
    raise exception 'You are not an active member of this kingdom';
  end if;

  select family.owner_id
  into v_owner_id
  from public.kingdoms kingdom
  join public.families family on family.id = kingdom.family_id
  where kingdom.id = p_kingdom_id;

  if v_owner_id = auth.uid() then
    raise exception 'The kingdom owner cannot leave their own kingdom';
  end if;

  delete from public.kingdom_members
  where id = v_membership.id;
end;
$$;

revoke all on function public.leave_kingdom(uuid) from public, anon;
grant execute on function public.leave_kingdom(uuid) to authenticated;

notify pgrst, 'reload schema';
