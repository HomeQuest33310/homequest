-- Return quests completed for the current period so the client can display
-- them separately from quests that are currently available.

create or replace function public.list_available_kingdom_quests(p_kingdom_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_member public.family_members;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select member.* into v_member
  from public.family_members member
  join public.kingdom_members kingdom_member on kingdom_member.member_id = member.id
  where kingdom_member.kingdom_id = p_kingdom_id
    and member.user_id = auth.uid()
    and member.is_active = true and kingdom_member.is_active = true
    and (member.expires_at is null or member.expires_at > now())
    and (kingdom_member.expires_at is null or kingdom_member.expires_at > now())
  limit 1;

  if v_member.id is null then raise exception 'Active kingdom membership required'; end if;

  select coalesce(jsonb_agg(row_data order by row_data->>'created_at' desc), '[]'::jsonb)
  into v_result
  from (
    select to_jsonb(quest) || jsonb_build_object(
      'is_completed_for_period', (
        not coalesce(public.homequest_quest_is_available_for_member(quest.id, v_member.id), false)
        and exists (
          select 1 from public.quest_completions completed
          where completed.quest_id = quest.id
            and completed.completed_by = v_member.id
            and completed.status = 'approved'
        )
      ),
      'assignees', coalesce((
        select jsonb_agg(jsonb_build_object(
          'member_id', member.id, 'user_id', member.user_id,
          'display_name', profile.display_name, 'role', kingdom_member.role
        ) order by profile.display_name)
        from public.quest_assignments assignment
        join public.family_members member on member.id = assignment.member_id
        join public.kingdom_members kingdom_member on kingdom_member.member_id = assignment.member_id
         and kingdom_member.kingdom_id = p_kingdom_id
        join public.profiles profile on profile.id = member.user_id
        where assignment.quest_id = quest.id
          and member.is_active = true and kingdom_member.is_active = true
          and (member.expires_at is null or member.expires_at > now())
          and (kingdom_member.expires_at is null or kingdom_member.expires_at > now())
      ), '[]'::jsonb),
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', skill.id, 'name', skill.name, 'icon', skill.icon, 'xp_reward', reward.xp_reward
        ) order by skill.name)
        from public.quest_skill_rewards reward
        join public.skills skill on skill.id = reward.skill_id
        where reward.quest_id = quest.id
      ), '[]'::jsonb)
    ) as row_data
    from public.quests quest
    where quest.kingdom_id = p_kingdom_id
      and quest.status = 'active'
      and (
        public.homequest_quest_is_available_for_member(quest.id, v_member.id)
        or exists (
          select 1 from public.quest_completions pending
          where pending.quest_id = quest.id
            and pending.completed_by = v_member.id
            and pending.status = 'pending'
        )
        or exists (
          select 1 from public.quest_completions completed
          where completed.quest_id = quest.id
            and completed.completed_by = v_member.id
            and completed.status = 'approved'
        )
      )
  ) available;

  return v_result;
end;
$function$;
