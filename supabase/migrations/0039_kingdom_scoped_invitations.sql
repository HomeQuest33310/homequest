-- Invitations now target one physical kingdom (home).
-- Family membership remains the guild identity; access and roles live on
-- kingdom_members so the same person can have different roles per home.

alter table public.family_invitations
  add column if not exists kingdom_id uuid
    references public.kingdoms(id) on delete cascade;

update public.family_invitations invitation
set kingdom_id = kingdom.id
from public.kingdoms kingdom
where invitation.kingdom_id is null
  and kingdom.family_id = invitation.family_id
  and kingdom.is_primary
  and kingdom.archived_at is null;

alter table public.family_invitations
  alter column kingdom_id set not null;

create index if not exists family_invitations_kingdom_status_idx
  on public.family_invitations(kingdom_id, status, created_at desc);

alter table public.kingdom_members
  add column if not exists membership_scope public.membership_scope
    not null default 'kingdom',
  add column if not exists domain_id uuid
    references public.domains(id) on delete set null;

alter table public.kingdom_members
  drop constraint if exists kingdom_members_scope_check;

alter table public.kingdom_members
  add constraint kingdom_members_scope_check check (
    (membership_scope = 'kingdom' and domain_id is null)
    or (membership_scope = 'domain' and domain_id is not null)
  );

create index if not exists kingdom_members_domain_idx
  on public.kingdom_members(domain_id)
  where domain_id is not null;

-- A member created through an invitation must not be silently added to the
-- primary kingdom. The accepting RPC creates the intended kingdom assignment.
create or replace function public.route_member_to_primary_kingdom()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  primary_kingdom_id uuid;
begin
  if new.invited_by is not null then
    return new;
  end if;

  select kingdom.id into primary_kingdom_id
  from public.kingdoms kingdom
  where kingdom.family_id = new.family_id
    and kingdom.is_primary
    and kingdom.archived_at is null
  limit 1;

  if primary_kingdom_id is not null then
    insert into public.kingdom_members (
      kingdom_id, member_id, role, membership_scope,
      is_active, expires_at, joined_at
    ) values (
      primary_kingdom_id,
      new.id,
      case
        when new.role = 'child' then 'adventurer'::public.family_role
        else new.role
      end,
      'kingdom',
      new.is_active,
      new.expires_at,
      coalesce(new.joined_at, now())
    )
    on conflict (kingdom_id, member_id) do update set
      role = excluded.role,
      membership_scope = excluded.membership_scope,
      domain_id = null,
      is_active = excluded.is_active,
      expires_at = excluded.expires_at;
  end if;
  return new;
end;
$$;

revoke all on function public.route_member_to_primary_kingdom()
  from public, anon, authenticated;

drop function if exists public.invite_family_member(
  uuid, text, public.family_role, public.membership_scope, uuid, integer
);

create function public.invite_family_member(
  p_family_id uuid,
  p_kingdom_id uuid,
  p_email text,
  p_role public.family_role default 'adventurer',
  p_membership_scope public.membership_scope default 'kingdom',
  p_domain_id uuid default null,
  p_expires_in_days integer default 7
)
returns public.family_invitations
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  created_invitation public.family_invitations;
  normalized_email text;
  is_family_owner boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.kingdoms kingdom
    where kingdom.id = p_kingdom_id
      and kingdom.family_id = p_family_id
      and kingdom.archived_at is null
  ) then
    raise exception 'Kingdom does not belong to this family';
  end if;

  select exists (
    select 1 from public.families family
    where family.id = p_family_id
      and family.owner_id = auth.uid()
  ) into is_family_owner;

  if not is_family_owner
     and not public.is_kingdom_guardian(p_kingdom_id) then
    raise exception 'Only this kingdom''s guardians can invite members';
  end if;

  if p_role = 'guardian' and not is_family_owner then
    raise exception 'Only the family founder can appoint a guardian';
  end if;

  if p_role not in ('guardian', 'adventurer', 'mercenary') then
    raise exception 'Unsupported invitation role';
  end if;

  normalized_email := lower(trim(p_email));
  if normalized_email = '' then raise exception 'Email is required'; end if;
  if p_expires_in_days < 1 or p_expires_in_days > 30 then
    raise exception 'Invitation duration must be between 1 and 30 days';
  end if;

  if p_role in ('guardian', 'adventurer') then
    p_membership_scope := 'kingdom';
    p_domain_id := null;
  end if;

  if p_membership_scope = 'domain' then
    if p_role <> 'mercenary' or p_domain_id is null then
      raise exception 'Only a mercenary can be limited to a domain';
    end if;
    if not exists (
      select 1 from public.domains domain
      where domain.id = p_domain_id
        and domain.kingdom_id = p_kingdom_id
        and domain.archived_at is null
    ) then
      raise exception 'Domain does not belong to this kingdom';
    end if;
  else
    p_domain_id := null;
  end if;

  update public.family_invitations
  set status = 'cancelled'
  where kingdom_id = p_kingdom_id
    and lower(email) = normalized_email
    and status = 'pending';

  insert into public.family_invitations (
    family_id, kingdom_id, domain_id, invited_by, email, role,
    membership_scope, status, expires_at
  ) values (
    p_family_id, p_kingdom_id, p_domain_id, auth.uid(), normalized_email,
    p_role, p_membership_scope, 'pending',
    now() + make_interval(days => p_expires_in_days)
  )
  returning * into created_invitation;

  return created_invitation;
end;
$$;

create or replace function public.accept_family_invitation(p_token uuid)
returns public.family_members
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  invitation public.family_invitations;
  accepted_membership public.family_members;
  inviter_membership_id uuid;
  current_email text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform public.create_profile_if_needed();

  select lower(coalesce(user_account.email, ''))
  into current_email
  from auth.users user_account
  where user_account.id = auth.uid();

  select * into invitation
  from public.family_invitations
  where token = p_token
  for update;

  if invitation.id is null then raise exception 'Invitation not found'; end if;
  if invitation.status <> 'pending' then
    raise exception 'Invitation is no longer pending';
  end if;
  if invitation.expires_at <= now() then
    update public.family_invitations set status = 'expired'
    where id = invitation.id;
    raise exception 'Invitation has expired';
  end if;
  if current_email = '' or current_email <> lower(invitation.email) then
    raise exception 'This invitation belongs to another email address';
  end if;

  select member.id into inviter_membership_id
  from public.family_members member
  where member.family_id = invitation.family_id
    and member.user_id = invitation.invited_by
  limit 1;

  select * into accepted_membership
  from public.family_members member
  where member.family_id = invitation.family_id
    and member.user_id = auth.uid()
  for update;

  if accepted_membership.id is null then
    insert into public.family_members (
      family_id, user_id, role, membership_scope, domain_id,
      expires_at, invited_by, accepted_at, is_active
    ) values (
      invitation.family_id, auth.uid(), 'adventurer', 'kingdom', null,
      null, invitation.invited_by, now(), true
    ) returning * into accepted_membership;
  else
    update public.family_members
    set is_active = true, accepted_at = now()
    where id = accepted_membership.id
    returning * into accepted_membership;
  end if;

  insert into public.kingdom_members (
    kingdom_id, member_id, role, membership_scope, domain_id,
    is_active, expires_at, assigned_by, joined_at
  ) values (
    invitation.kingdom_id,
    accepted_membership.id,
    invitation.role,
    invitation.membership_scope,
    invitation.domain_id,
    true,
    case when invitation.role = 'mercenary'
      then invitation.expires_at else null end,
    inviter_membership_id,
    now()
  )
  on conflict (kingdom_id, member_id) do update set
    role = excluded.role,
    membership_scope = excluded.membership_scope,
    domain_id = excluded.domain_id,
    is_active = true,
    expires_at = excluded.expires_at,
    assigned_by = excluded.assigned_by;

  update public.family_invitations
  set status = 'accepted', accepted_by = auth.uid(), accepted_at = now()
  where id = invitation.id;

  return accepted_membership;
end;
$$;

revoke all on function public.invite_family_member(
  uuid, uuid, text, public.family_role,
  public.membership_scope, uuid, integer
) from public, anon;
grant execute on function public.invite_family_member(
  uuid, uuid, text, public.family_role,
  public.membership_scope, uuid, integer
) to authenticated;

revoke all on function public.accept_family_invitation(uuid)
  from public, anon;
grant execute on function public.accept_family_invitation(uuid)
  to authenticated;

drop policy if exists "Guardians can read family invitations"
on public.family_invitations;

create policy "Kingdom guardians and recipients can read invitations"
on public.family_invitations for select to authenticated
using (
  (select public.is_kingdom_guardian(kingdom_id))
  or exists (
    select 1 from public.families family
    where family.id = family_invitations.family_id
      and family.owner_id = (select auth.uid())
  )
  or lower(email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
);

-- A family member only discovers homes to which they are assigned. The family
-- founder keeps access to every home in order to appoint guardians.
drop policy if exists "Family members can read kingdoms" on public.kingdoms;
create policy "Assigned members can read kingdoms"
on public.kingdoms for select to authenticated
using (
  (select public.is_kingdom_member(id))
  or exists (
    select 1 from public.families family
    where family.id = kingdoms.family_id
      and family.owner_id = (select auth.uid())
  )
);

notify pgrst, 'reload schema';
