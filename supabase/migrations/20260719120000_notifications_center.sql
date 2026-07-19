-- HomeQuest: notification center for every active kingdom member.

alter table public.guardian_notifications
  drop constraint if exists guardian_notifications_kind_check;

alter table public.guardian_notifications
  add constraint guardian_notifications_kind_check check (kind in (
    'quest_joined', 'voluntary_quest_request', 'quest_assigned',
    'completion_pending', 'completion_approved', 'completion_rejected',
    'reward_unlocked', 'boss_defeated'
  ));

drop policy if exists "Guardians can read their notifications"
  on public.guardian_notifications;
create policy "Members can read their notifications"
  on public.guardian_notifications for select to authenticated
  using (exists (
    select 1 from public.family_members fm
    where fm.id = guardian_notifications.recipient_member_id
      and fm.user_id = (select auth.uid())
      and fm.is_active = true
      and (fm.expires_at is null or fm.expires_at > now())
  ));

create or replace function public.list_my_notifications(p_family_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth
as $$
declare v_member public.family_members; v_result jsonb;
begin
  select * into v_member from public.family_members
  where family_id = p_family_id and user_id = auth.uid() and is_active = true
    and (expires_at is null or expires_at > now()) limit 1;
  if v_member.id is null then raise exception 'Active family membership required'; end if;
  select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at desc), '[]'::jsonb)
    into v_result from (select * from public.guardian_notifications
      where family_id = p_family_id and recipient_member_id = v_member.id
      order by created_at desc limit 100) n;
  return v_result;
end; $$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns public.guardian_notifications language plpgsql security definer
set search_path = public, auth as $$
declare v_notification public.guardian_notifications;
begin
  update public.guardian_notifications n set read_at = coalesce(n.read_at, now())
  where n.id = p_notification_id and exists (select 1 from public.family_members fm
    where fm.id = n.recipient_member_id and fm.user_id = auth.uid() and fm.is_active = true)
  returning * into v_notification;
  if v_notification.id is null then raise exception 'Notification not found'; end if;
  return v_notification;
end; $$;

create or replace function public.mark_all_notifications_read(p_family_id uuid)
returns integer language plpgsql security definer set search_path = public, auth
as $$
declare v_member public.family_members; v_count integer;
begin
  select * into v_member from public.family_members where family_id = p_family_id
    and user_id = auth.uid() and is_active = true limit 1;
  if v_member.id is null then raise exception 'Active family membership required'; end if;
  update public.guardian_notifications set read_at = coalesce(read_at, now())
    where family_id = p_family_id and recipient_member_id = v_member.id and read_at is null;
  get diagnostics v_count = row_count; return v_count;
end; $$;

revoke all on function public.list_my_notifications(uuid) from public;
revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.mark_all_notifications_read(uuid) from public;
grant execute on function public.list_my_notifications(uuid) to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read(uuid) to authenticated;

create or replace function public.notify_quest_assignment()
returns trigger language plpgsql security definer set search_path = public, auth as $$
declare v_quest public.quests; v_name text;
begin
  select * into v_quest from public.quests where id = new.quest_id;
  select display_name into v_name from public.profiles p join public.family_members fm on fm.user_id = p.id where fm.id = new.member_id;
  insert into public.guardian_notifications(family_id, recipient_member_id, quest_id, kind, title, body)
    values (v_quest.family_id, new.member_id, new.quest_id, 'quest_assigned', 'Nouvelle mission', 'La mission « ' || v_quest.title || ' » vous est maintenant attribuée.');
  return new;
end; $$;

drop trigger if exists quest_assignment_notification on public.quest_assignments;
create trigger quest_assignment_notification after insert on public.quest_assignments
  for each row execute function public.notify_quest_assignment();

create or replace function public.notify_completion_change()
returns trigger language plpgsql security definer set search_path = public, auth as $$
declare v_quest public.quests; v_name text; v_guardian public.family_members;
begin
  select * into v_quest from public.quests where id = new.quest_id;
  select display_name into v_name from public.profiles p join public.family_members fm on fm.user_id = p.id where fm.id = new.completed_by;
  if tg_op = 'INSERT' and new.status = 'pending' then
    for v_guardian in select * from public.family_members where family_id = v_quest.family_id and role = 'guardian' and is_active = true loop
      insert into public.guardian_notifications(family_id, recipient_member_id, actor_member_id, quest_id, kind, title, body)
      values(v_quest.family_id, v_guardian.id, new.completed_by, new.quest_id, 'completion_pending', 'Validation requise', v_name || ' a terminé « ' || v_quest.title || ' ».');
    end loop;
  elsif tg_op = 'UPDATE' and new.status in ('approved','rejected')
    and (old.status is distinct from new.status) then
    insert into public.guardian_notifications(family_id, recipient_member_id, actor_member_id, quest_id, kind, title, body)
      values(v_quest.family_id, new.completed_by, null, new.quest_id,
        case when new.status = 'approved' then 'completion_approved' else 'completion_rejected' end,
        case when new.status = 'approved' then 'Mission validée' else 'Mission à revoir' end,
        case when new.status = 'approved' then 'Votre mission « ' || v_quest.title || ' » a été validée.' else 'Votre mission « ' || v_quest.title || ' » doit être revue.' end);
  end if;
  return new;
end; $$;

drop trigger if exists quest_completion_notification on public.quest_completions;
create trigger quest_completion_notification after insert or update of status on public.quest_completions
  for each row execute function public.notify_completion_change();
