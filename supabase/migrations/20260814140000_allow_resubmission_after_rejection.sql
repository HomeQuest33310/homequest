-- A rejected completion can be submitted again. Refresh the existing
-- notification instead of violating its deduplication key.

create or replace function public.notify_completion_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_quest public.quests;
  v_name text;
  v_guardian public.family_members;
begin
  select * into v_quest from public.quests where id = new.quest_id;
  select display_name into v_name
  from public.profiles p
  join public.family_members fm on fm.user_id = p.id
  where fm.id = new.completed_by;

  if tg_op = 'INSERT' and new.status = 'pending' then
    for v_guardian in
      select * from public.family_members
      where family_id = v_quest.family_id and role = 'guardian' and is_active = true
    loop
      insert into public.guardian_notifications(
        family_id, recipient_member_id, actor_member_id, quest_id,
        kind, title, body
      ) values (
        v_quest.family_id, v_guardian.id, new.completed_by, new.quest_id,
        'completion_pending', 'Validation requise',
        v_name || ' a terminé « ' || v_quest.title || ' ». '
      )
      on conflict (recipient_member_id, quest_id, actor_member_id, kind)
      do update set created_at = now(), read_at = null,
                    title = excluded.title, body = excluded.body;
    end loop;
  elsif tg_op = 'UPDATE'
    and new.status in ('approved', 'rejected')
    and old.status is distinct from new.status then
    insert into public.guardian_notifications(
      family_id, recipient_member_id, actor_member_id, quest_id,
      kind, title, body
    ) values (
      v_quest.family_id, new.completed_by, null, new.quest_id,
      case when new.status = 'approved' then 'completion_approved'
           else 'completion_rejected' end,
      case when new.status = 'approved' then 'Mission validée'
           else 'Mission à revoir' end,
      case when new.status = 'approved' then
        'Votre mission « ' || v_quest.title || ' » a été validée. Gains personnels : +'
        || v_quest.xp_reward || ' XP, +' || v_quest.gold_reward || ' or et +'
        || v_quest.boss_damage || ' dégâts au boss.'
      else 'Votre mission « ' || v_quest.title || ' » doit être revue.' end
    )
    on conflict (recipient_member_id, quest_id, actor_member_id, kind)
    do update set created_at = now(), read_at = null,
                  title = excluded.title, body = excluded.body;
  end if;
  return new;
end;
$function$;
