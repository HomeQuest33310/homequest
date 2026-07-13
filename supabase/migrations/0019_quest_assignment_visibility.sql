-- HomeQuest v0.5.4-alpha
-- Available quests expose their active assignees. A quest without assignees is
-- a free recruitment mission by default.

create or replace function public.list_available_quests(
  p_family_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_family_member(p_family_id) then
    raise exception 'Active family membership required';
  end if;

  select coalesce(
    jsonb_agg(row_data order by row_data->>'created_at' desc),
    '[]'::jsonb
  )
  into v_result
  from (
    select to_jsonb(q) || jsonb_build_object(
      'assignees', coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'member_id', fm.id,
              'user_id', fm.user_id,
              'display_name', p.display_name,
              'role', fm.role
            )
            order by p.display_name
          )
          from public.quest_assignments qa
          join public.family_members fm on fm.id = qa.member_id
          join public.profiles p on p.id = fm.user_id
          where qa.quest_id = q.id
            and fm.is_active = true
            and (fm.expires_at is null or fm.expires_at > now())
        ),
        '[]'::jsonb
      )
    ) as row_data
    from public.quests q
    where q.family_id = p_family_id
      and public.homequest_quest_is_available(q.id)
  ) available;

  return v_result;
end;
$$;

revoke all on function public.list_available_quests(uuid) from public, anon;
grant execute on function public.list_available_quests(uuid) to authenticated;

notify pgrst, 'reload schema';
