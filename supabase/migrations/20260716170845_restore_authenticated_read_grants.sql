-- HomeQuest - Restore explicit API read grants for legacy tables.
--
-- Recent Supabase projects no longer expose tables through implicit default
-- privileges. RLS policies still decide which rows a signed-in user may read;
-- these grants only allow PostgREST to evaluate those policies.

revoke select on table
  public.families,
  public.domains,
  public.family_invitations,
  public.profiles,
  public.skills
from anon;

grant select on table
  public.families,
  public.domains,
  public.family_invitations,
  public.profiles,
  public.skills
to authenticated;

notify pgrst, 'reload schema';
