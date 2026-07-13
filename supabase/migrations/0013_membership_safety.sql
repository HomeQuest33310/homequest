-- HomeQuest v0.4.2-alpha
-- Harden membership checks and protect the last active guardian.

create or replace function public.is_family_member(target_family_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = auth.uid()
      and fm.is_active = true
      and (fm.expires_at is null or fm.expires_at > now())
  );
$$;

create or replace function public.is_family_guardian(target_family_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = auth.uid()
      and fm.role = 'guardian'
      and fm.is_active = true
      and (fm.expires_at is null or fm.expires_at > now())
  );
$$;

create or replace function public.change_family_member_role(
  p_member_id uuid,
  p_new_role family_role
)
returns public.family_members
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_member public.family_members;
  updated_member public.family_members;
  kingdom_owner_id uuid;
  active_guardian_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into target_member
  from public.family_members
  where id = p_member_id
  for update;

  if target_member.id is null then
    raise exception 'Family member not found';
  end if;

  if not public.is_family_guardian(target_member.family_id) then
    raise exception 'Only guardians can change member roles';
  end if;

  if p_new_role not in ('guardian', 'adventurer', 'mercenary') then
    raise exception 'Unsupported role';
  end if;

  select owner_id into kingdom_owner_id
  from public.families
  where id = target_member.family_id;

  if target_member.user_id = kingdom_owner_id
     and p_new_role <> 'guardian' then
    raise exception 'The kingdom owner must remain a guardian';
  end if;

  if target_member.role = 'guardian' and p_new_role <> 'guardian' then
    select count(*) into active_guardian_count
    from public.family_members fm
    where fm.family_id = target_member.family_id
      and fm.role = 'guardian'
      and fm.is_active = true
      and (fm.expires_at is null or fm.expires_at > now());

    if active_guardian_count <= 1 then
      raise exception 'The kingdom must keep at least one active guardian';
    end if;
  end if;

  update public.family_members
  set
    role = p_new_role,
    membership_scope = case
      when p_new_role in ('guardian', 'adventurer')
        then 'kingdom'::membership_scope
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
  where id = p_member_id
  returning * into updated_member;

  return updated_member;
end;
$$;

revoke all on function public.is_family_member(uuid) from public;
revoke all on function public.is_family_guardian(uuid) from public;
grant execute on function public.is_family_member(uuid) to authenticated;
grant execute on function public.is_family_guardian(uuid) to authenticated;

notify pgrst, 'reload schema';
