alter table public.guardian_notifications
  drop constraint if exists guardian_notifications_kind_check;

alter table public.guardian_notifications
  add constraint guardian_notifications_kind_check
  check (kind in ('quest_joined', 'voluntary_quest_request'));
