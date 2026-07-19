-- Add contextual guidance and a safe in-app destination to notifications.
alter table public.guardian_notifications
  add column if not exists action_route text,
  add column if not exists action_label text;

-- Existing notifications remain valid; new notifications may point only to
-- internal application routes and never contain arbitrary external URLs.
alter table public.guardian_notifications
  add constraint guardian_notifications_action_route_check
  check (action_route is null or action_route like '/%');

create or replace function public.homequest_notification_guidance()
returns trigger language plpgsql as $$
begin
  if new.action_route is null then
    new.action_route := case
      when new.kind in ('quest_joined', 'quest_assigned', 'completion_pending',
                        'completion_approved', 'completion_rejected') then '/missions'
      when new.kind = 'voluntary_quest_request' then '/quest-requests'
      when new.kind = 'reward_unlocked' then '/reward-suggestions'
      when new.kind = 'boss_defeated' then '/bosses'
      else null
    end;
  end if;
  if new.action_label is null then
    new.action_label := case
      when new.kind in ('quest_joined', 'quest_assigned', 'completion_pending',
                        'completion_approved', 'completion_rejected') then 'Voir les missions'
      when new.kind = 'voluntary_quest_request' then 'Voir les initiatives'
      when new.kind = 'reward_unlocked' then 'Voir les récompenses'
      when new.kind = 'boss_defeated' then 'Voir les boss'
      else null
    end;
  end if;
  return new;
end; $$;

drop trigger if exists guardian_notification_guidance on public.guardian_notifications;
create trigger guardian_notification_guidance
  before insert on public.guardian_notifications
  for each row execute function public.homequest_notification_guidance();

update public.guardian_notifications
set action_route = case
      when kind in ('quest_joined', 'quest_assigned', 'completion_pending',
                    'completion_approved', 'completion_rejected') then '/missions'
      when kind = 'voluntary_quest_request' then '/quest-requests'
      when kind = 'reward_unlocked' then '/reward-suggestions'
      when kind = 'boss_defeated' then '/bosses'
      else action_route end,
    action_label = case
      when kind in ('quest_joined', 'quest_assigned', 'completion_pending',
                    'completion_approved', 'completion_rejected') then 'Voir les missions'
      when kind = 'voluntary_quest_request' then 'Voir les initiatives'
      when kind = 'reward_unlocked' then 'Voir les récompenses'
      when kind = 'boss_defeated' then 'Voir les boss'
      else action_label end
where action_route is null or action_label is null;
