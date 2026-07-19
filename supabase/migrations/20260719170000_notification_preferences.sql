create table if not exists public.notification_preferences (
  member_id uuid primary key references public.family_members(id) on delete cascade,
  quest_notifications boolean not null default true,
  validation_notifications boolean not null default true,
  reward_notifications boolean not null default true,
  boss_notifications boolean not null default true,
  quiet_hours_enabled boolean not null default false,
  quiet_start time,
  quiet_end time,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;
drop policy if exists "Members manage their notification preferences" on public.notification_preferences;
create policy "Members manage their notification preferences"
  on public.notification_preferences for all to authenticated
  using (exists (select 1 from public.family_members fm
    where fm.id = notification_preferences.member_id and fm.user_id = (select auth.uid())
      and fm.is_active = true))
  with check (exists (select 1 from public.family_members fm
    where fm.id = notification_preferences.member_id and fm.user_id = (select auth.uid())
      and fm.is_active = true));

grant select, insert, update on public.notification_preferences to authenticated;
