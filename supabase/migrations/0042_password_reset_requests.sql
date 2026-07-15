-- Audit and rate-limit guardian-triggered password recovery requests.
-- This table is intentionally inaccessible through the public Data API.

create table if not exists public.password_reset_requests (
  id uuid primary key default gen_random_uuid(),
  kingdom_id uuid not null references public.kingdoms(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now()
);

create index if not exists password_reset_requests_target_recent_idx
  on public.password_reset_requests(target_user_id, requested_at desc);

create index if not exists password_reset_requests_requester_recent_idx
  on public.password_reset_requests(requested_by, requested_at desc);

alter table public.password_reset_requests enable row level security;

revoke all on table public.password_reset_requests from public, anon, authenticated;

comment on table public.password_reset_requests is
  'Private audit trail for guardian-triggered password recovery emails.';
