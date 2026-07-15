-- HomeQuest security hardening before public release.
--
-- 1. Membership rows may only be created by the SECURITY DEFINER workflows
--    create_kingdom() and accept_family_invitation().
-- 2. Reward suggestions must belong to the proposer's actual family.
-- 3. Profiles are visible only to their owner and active members of a shared
--    family.

-- Direct membership writes would allow a signed-in user to manufacture a
-- membership or role. The approved RPC workflows run with their owner's
-- privileges and remain responsible for validating the caller and invitation.
drop policy if exists "Family owners can create first guardian membership"
  on public.family_members;
drop policy if exists "Guardians can insert family members"
  on public.family_members;

revoke insert, update, delete on table public.family_members
  from anon, authenticated;
grant select on table public.family_members to authenticated;

-- Qualify the outer table explicitly. Without this qualification PostgreSQL
-- resolves both sides to the inner family_members row, making the comparison
-- tautological.
drop policy if exists "Adventurers can propose their own rewards"
  on public.reward_suggestions;

create policy "Adventurers can propose their own rewards"
on public.reward_suggestions
for insert
to authenticated
with check (
  status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and exists (
    select 1
    from public.family_members member
    where member.id = reward_suggestions.proposed_by
      and member.family_id = reward_suggestions.family_id
      and member.user_id = (select auth.uid())
      and member.role in ('adventurer', 'mercenary')
      and member.is_active
      and (member.expires_at is null or member.expires_at > now())
  )
);

-- Reading every profile in the project is unnecessary for a family app.
-- Keep the user's own profile readable during onboarding, then allow profiles
-- only when both users are active members of at least one shared family.
drop policy if exists "Profiles are readable by authenticated users"
  on public.profiles;
drop policy if exists "Profiles are readable by shared family members"
  on public.profiles;

create policy "Profiles are readable by shared family members"
on public.profiles
for select
to authenticated
using (
  profiles.id = (select auth.uid())
  or exists (
    select 1
    from public.family_members viewer
    join public.family_members target
      on target.family_id = viewer.family_id
    where viewer.user_id = (select auth.uid())
      and target.user_id = profiles.id
      and viewer.is_active
      and target.is_active
      and (viewer.expires_at is null or viewer.expires_at > now())
      and (target.expires_at is null or target.expires_at > now())
  )
);

create index if not exists family_members_active_user_family_idx
  on public.family_members (user_id, family_id)
  where is_active;

notify pgrst, 'reload schema';
