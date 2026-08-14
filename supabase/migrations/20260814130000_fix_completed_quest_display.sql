-- Completed one-time quests are completed for the whole kingdom. Recurring
-- quests are completed for the current member until their next occurrence.

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
  where kingdom_member.kingdom_id = p_kingdom_id and member.user_id = auth.uid()
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
        (quest.frequency = 'once' and exists (
          select 1 from public.quest_completions c
          where c.quest_id = quest.id and c.status = 'approved'
        ))
        or (quest.frequency <> 'once'
          and not coalesce(public.homequest_quest_is_available_for_member(quest.id, v_member.id), false)
          and exists (
            select 1 from public.quest_completions c
            where c.quest_id = quest.id and c.completed_by = v_member.id and c.status = 'approved'
          ))
      ),
      'assignees', coalesce((
        select jsonb_agg(jsonb_build_object(
          'member_id', m.id, 'user_id', m.user_id,
          'display_name', p.display_name, 'role', km.role
        ) order by p.display_name)
        from public.quest_assignments a
        join public.family_members m on m.id = a.member_id
        join public.kingdom_members km on km.member_id = a.member_id
         and km.kingdom_id = p_kingdom_id
        join public.profiles p on p.id = m.user_id
        where a.quest_id = quest.id and m.is_active = true and km.is_active = true
          and (m.expires_at is null or m.expires_at > now())
          and (km.expires_at is null or km.expires_at > now())
      ), '[]'::jsonb),
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', s.id, 'name', s.name, 'icon', s.icon, 'xp_reward', r.xp_reward
        ) order by s.name)
        from public.quest_skill_rewards r
        join public.skills s on s.id = r.skill_id
        where r.quest_id = quest.id
      ), '[]'::jsonb)
    ) as row_data
    from public.quests quest
    where quest.kingdom_id = p_kingdom_id and quest.status = 'active'
      and (
        public.homequest_quest_is_available_for_member(quest.id, v_member.id)
        or exists (
          select 1 from public.quest_completions p
          where p.quest_id = quest.id and p.completed_by = v_member.id and p.status = 'pending'
        )
        or exists (
          select 1 from public.quest_completions c
          where c.quest_id = quest.id and c.status = 'approved'
            and (quest.frequency = 'once' or c.completed_by = v_member.id)
        )
      )
  ) available;
  return v_result;
end;
$function$;
