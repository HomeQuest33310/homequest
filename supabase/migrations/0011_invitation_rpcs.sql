-- HomeQuest v0.4.1-alpha
-- Invitations et gestion des rôles.
--
-- Règles principales :
-- - seuls les Gardiens actifs peuvent inviter, annuler une invitation,
--   modifier un rôle ou désactiver un membre ;
-- - un Aventurier rejoint le Royaume ;
-- - un Mercenaire peut rejoindre le Royaume ou un Domaine ;
-- - le propriétaire du Royaume ne peut pas être rétrogradé ou désactivé ;
-- - une invitation ne peut être acceptée que par l'adresse email invitée.

-- ============================================================
-- 1. Inviter un membre
-- ============================================================

create or replace function public.invite_family_member(
  p_family_id uuid,
  p_email text,
  p_role family_role default 'adventurer',
  p_membership_scope membership_scope default 'kingdom',
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
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can invite members';
  end if;

  normalized_email := lower(trim(p_email));

  if normalized_email = '' then
    raise exception 'Email is required';
  end if;

  if p_role not in ('guardian', 'adventurer', 'mercenary') then
    raise exception 'Unsupported invitation role';
  end if;

  if p_expires_in_days < 1 or p_expires_in_days > 30 then
    raise exception 'Invitation duration must be between 1 and 30 days';
  end if;

  -- Les Gardiens et Aventuriers rejoignent toujours le Royaume entier.
  if p_role in ('guardian', 'adventurer') then
    p_membership_scope := 'kingdom';
    p_domain_id := null;
  end if;

  if p_membership_scope = 'domain' then
    if p_domain_id is null then
      raise exception 'A domain is required for a domain invitation';
    end if;

    if not exists (
      select 1
      from public.domains d
      where d.id = p_domain_id
        and d.family_id = p_family_id
    ) then
      raise exception 'Domain does not belong to this kingdom';
    end if;
  else
    p_domain_id := null;
  end if;

  -- Annule les anciennes invitations en attente pour la même adresse.
  update public.family_invitations
  set status = 'cancelled'
  where family_id = p_family_id
    and lower(email) = normalized_email
    and status = 'pending';

  insert into public.family_invitations (
    family_id,
    domain_id,
    invited_by,
    email,
    role,
    membership_scope,
    status,
    expires_at
  )
  values (
    p_family_id,
    p_domain_id,
    auth.uid(),
    normalized_email,
    p_role,
    p_membership_scope,
    'pending',
    now() + make_interval(days => p_expires_in_days)
  )
  returning *
  into created_invitation;

  return created_invitation;
end;
$$;


-- ============================================================
-- 2. Accepter une invitation
-- ============================================================

create or replace function public.accept_family_invitation(
  p_token uuid
)
returns public.family_members
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  invitation public.family_invitations;
  accepted_membership public.family_members;
  current_email text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  perform public.create_profile_if_needed();

  current_email := lower(
    coalesce(
      auth.jwt() ->> 'email',
      ''
    )
  );

  select *
  into invitation
  from public.family_invitations
  where token = p_token
  for update;

  if invitation.id is null then
    raise exception 'Invitation not found';
  end if;

  if invitation.status <> 'pending' then
    raise exception 'Invitation is no longer pending';
  end if;

  if invitation.expires_at <= now() then
    update public.family_invitations
    set status = 'expired'
    where id = invitation.id;

    raise exception 'Invitation has expired';
  end if;

  if current_email = '' or current_email <> lower(invitation.email) then
    raise exception 'This invitation belongs to another email address';
  end if;

  insert into public.family_members (
    family_id,
    user_id,
    role,
    expires_at,
    membership_scope,
    domain_id,
    invited_by,
    accepted_at,
    is_active
  )
  values (
    invitation.family_id,
    auth.uid(),
    invitation.role,
    case
      when invitation.role = 'mercenary'
        then invitation.expires_at
      else null
    end,
    invitation.membership_scope,
    invitation.domain_id,
    invitation.invited_by,
    now(),
    true
  )
  on conflict (family_id, user_id)
  do update set
    role = excluded.role,
    expires_at = excluded.expires_at,
    membership_scope = excluded.membership_scope,
    domain_id = excluded.domain_id,
    invited_by = excluded.invited_by,
    accepted_at = now(),
    is_active = true
  returning *
  into accepted_membership;

  update public.family_invitations
  set
    status = 'accepted',
    accepted_by = auth.uid(),
    accepted_at = now()
  where id = invitation.id;

  return accepted_membership;
end;
$$;


-- ============================================================
-- 3. Annuler une invitation
-- ============================================================

create or replace function public.cancel_family_invitation(
  p_invitation_id uuid
)
returns public.family_invitations
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  invitation public.family_invitations;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into invitation
  from public.family_invitations
  where id = p_invitation_id
  for update;

  if invitation.id is null then
    raise exception 'Invitation not found';
  end if;

  if not public.is_family_guardian(invitation.family_id) then
    raise exception 'Only guardians can cancel invitations';
  end if;

  if invitation.status <> 'pending' then
    raise exception 'Only pending invitations can be cancelled';
  end if;

  update public.family_invitations
  set status = 'cancelled'
  where id = p_invitation_id
  returning *
  into invitation;

  return invitation;
end;
$$;


-- ============================================================
-- 4. Modifier le rôle d’un membre
-- ============================================================

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
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into target_member
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

  select owner_id
  into kingdom_owner_id
  from public.families
  where id = target_member.family_id;

  if target_member.user_id = kingdom_owner_id
     and p_new_role <> 'guardian' then
    raise exception 'The kingdom owner must remain a guardian';
  end if;

  -- Un Gardien ou Aventurier appartient à tout le Royaume.
  update public.family_members
  set
    role = p_new_role,
    membership_scope = case
      when p_new_role in ('guardian', 'adventurer')
        then 'kingdom'::membership_scope
      else membership_scope
    end,
    domain_id = case
      when p_new_role in ('guardian', 'adventurer')
        then null
      else domain_id
    end,
    expires_at = case
      when p_new_role <> 'mercenary'
        then null
      else expires_at
    end
  where id = p_member_id
  returning *
  into updated_member;

  return updated_member;
end;
$$;


-- ============================================================
-- 5. Désactiver un membre
-- ============================================================

create or replace function public.deactivate_family_member(
  p_member_id uuid
)
returns public.family_members
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_member public.family_members;
  deactivated_member public.family_members;
  kingdom_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into target_member
  from public.family_members
  where id = p_member_id
  for update;

  if target_member.id is null then
    raise exception 'Family member not found';
  end if;

  if not public.is_family_guardian(target_member.family_id) then
    raise exception 'Only guardians can deactivate members';
  end if;

  select owner_id
  into kingdom_owner_id
  from public.families
  where id = target_member.family_id;

  if target_member.user_id = kingdom_owner_id then
    raise exception 'The kingdom owner cannot be deactivated';
  end if;

  update public.family_members
  set
    is_active = false,
    expires_at = coalesce(expires_at, now())
  where id = p_member_id
  returning *
  into deactivated_member;

  return deactivated_member;
end;
$$;


-- ============================================================
-- 6. Permissions d’exécution
-- ============================================================

revoke all on function public.invite_family_member(
  uuid,
  text,
  family_role,
  membership_scope,
  uuid,
  integer
) from public;

revoke all on function public.accept_family_invitation(uuid) from public;
revoke all on function public.cancel_family_invitation(uuid) from public;
revoke all on function public.change_family_member_role(uuid, family_role) from public;
revoke all on function public.deactivate_family_member(uuid) from public;

grant execute on function public.invite_family_member(
  uuid,
  text,
  family_role,
  membership_scope,
  uuid,
  integer
) to authenticated;

grant execute on function public.accept_family_invitation(uuid)
to authenticated;

grant execute on function public.cancel_family_invitation(uuid)
to authenticated;

grant execute on function public.change_family_member_role(uuid, family_role)
to authenticated;

grant execute on function public.deactivate_family_member(uuid)
to authenticated;


-- ============================================================
-- 7. Accès en lecture aux invitations
-- ============================================================

drop policy if exists
  "Guardians can read family invitations"
on public.family_invitations;

create policy
  "Guardians can read family invitations"
on public.family_invitations
for select
to authenticated
using (
  public.is_family_guardian(family_id)
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
);