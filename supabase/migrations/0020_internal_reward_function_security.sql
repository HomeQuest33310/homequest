-- HomeQuest v0.6.0-alpha
-- Keep reward application internal to the completion review workflow.

alter function public.homequest_level_for_xp(integer)
  set search_path = public;

revoke execute on function public.apply_quest_completion_rewards(
  uuid,
  uuid,
  boolean
) from public, anon, authenticated;

notify pgrst, 'reload schema';
