-- Allow the recipient of a private invitation to decline it without joining.

create or replace function public.decline_family_invitation(
  p_token uuid
)
returns public.family_invitations
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  invitation public.family_invitations;
  current_email text;
begin
  select * into invitation
  from public.family_invitations
  where token = p_token
  for update;

  if invitation.id is null then
    raise exception 'Invitation not found';
  end if;
  if invitation.status <> 'pending' then
    raise exception 'Only pending invitations can be declined';
  end if;

  if auth.uid() is not null then
    select lower(coalesce(user_account.email, ''))
    into current_email
    from auth.users user_account
    where user_account.id = auth.uid();

    if current_email <> lower(invitation.email) then
      raise exception 'This invitation belongs to another email address';
    end if;
  end if;

  update public.family_invitations
  set status = 'declined'
  where id = invitation.id
  returning * into invitation;

  return invitation;
end;
$$;

revoke all on function public.decline_family_invitation(uuid)
  from public;
grant execute on function public.decline_family_invitation(uuid)
  to anon, authenticated;

notify pgrst, 'reload schema';
