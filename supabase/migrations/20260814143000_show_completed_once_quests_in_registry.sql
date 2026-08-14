-- Keep completed one-time quests in the Grand Register even after they are
-- archived, so they appear under "Terminées pour cette période".

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
  join public.kingdom_members km on km.member_id = member.id
  where km.kingdom_id = p_kingdom_id and member.user_id = auth.uid()
    and member.is_active = true and km.is_active = true
    and (member.expires_at is null or member.expires_at > now())
    and (km.expires_at is null or km.expires_at > now())
  limit 1;
  if v_member.id is null then raise exception 'Active kingdom membership required'; end if;

  select coalesce(jsonb_agg(row_data order by row_data->>'created_at' desc), '[]'::jsonb)
  into v_result
  from (
    select to_jsonb(q) || jsonb_build_object(
      'is_completed_for_period', (
        (q.frequency = 'once' and exists (
          select 1 from public.quest_completions c
          where c.quest_id = q.id and c.status in ('approved', 'pending')
        ))
        or (q.frequency in ('daily', 'weekly')
          and not coalesce(public.homequest_quest_is_available_for_member(q.id, v_member.id), false)
          and exists (
            select 1 from public.quest_completions c
            where c.quest_id = q.id and c.status in ('approved', 'pending')
          ))
      ),
      'assignees', coalesce((
        select jsonb_agg(jsonb_build_object(
          'member_id', m.id, 'user_id', m.user_id,
          'display_name', p.display_name, 'role', km2.role
        ) order by p.display_name)
        from public.quest_assignments a
        join public.family_members m on m.id = a.member_id
        join public.kingdom_members km2 on km2.member_id = a.member_id
         and km2.kingdom_id = p_kingdom_id
        join public.profiles p on p.id = m.user_id
        where a.quest_id = q.id and m.is_active = true and km2.is_active = true
          and (m.expires_at is null or m.expires_at > now())
          and (km2.expires_at is null or km2.expires_at > now())
      ), '[]'::jsonb),
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', s.id, 'name', s.name, 'icon', s.icon, 'xp_reward', r.xp_reward
        ) order by s.name)
        from public.quest_skill_rewards r
        join public.skills s on s.id = r.skill_id
        where r.quest_id = q.id
      ), '[]'::jsonb)
    ) as row_data
    from public.quests q
    where q.kingdom_id = p_kingdom_id
      and (
        q.status = 'active'
        or (q.frequency = 'once' and exists (
          select 1 from public.quest_completions c
          where c.quest_id = q.id and c.status in ('approved', 'pending')
        ))
      )
  ) available;
  return v_result;
end;
$function$;
