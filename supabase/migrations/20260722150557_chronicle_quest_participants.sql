-- Keep the legend readable by listing the people credited for the mission.

create or replace function public.sync_quest_chronicle_participants()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quest public.quests;
  v_participants text;
begin
  if new.kind <> 'completion_approved' or new.quest_id is null then
    return new;
  end if;

  select * into v_quest
  from public.quests
  where id = new.quest_id;

  select string_agg(distinct profile.display_name, ', ' order by profile.display_name)
  into v_participants
  from public.guardian_notifications notification
  join public.family_members member
    on member.id = notification.recipient_member_id
  join public.profiles profile
    on profile.id = member.user_id
  where notification.quest_id = new.quest_id
    and notification.kind = 'completion_approved'
    and notification.created_at >= now() - interval '1 minute';

  if v_participants is null then
    return new;
  end if;

  update public.chronicles chronicle
  set title = 'Mission « ' || v_quest.title || ' » réalisée par ' || v_participants,
      body = 'Participants crédités : ' || v_participants ||
        '. La mission a été validée et les récompenses ont été distribuées.'
  where chronicle.id = (
    select recent.id
    from public.chronicles recent
    where recent.family_id = v_quest.family_id
      and recent.type = 'quest_completed'
      and recent.created_at >= now() - interval '1 minute'
    order by recent.created_at desc
    limit 1
  );

  return new;
end;
$$;

drop trigger if exists quest_completion_chronicle_participants
on public.guardian_notifications;
create trigger quest_completion_chronicle_participants
after insert on public.guardian_notifications
for each row execute function public.sync_quest_chronicle_participants();

notify pgrst, 'reload schema';
