-- HomeQuest v0.4.1-alpha
-- Profils, rôles, périmètres et invitations.

create type membership_scope as enum ('kingdom', 'domain');

create type invitation_status as enum (
  'pending',
  'accepted',
  'declined',
  'expired',
  'cancelled'
);

alter table public.family_members
  add column if not exists membership_scope membership_scope
    not null default 'kingdom',
  add column if not exists domain_id uuid
    references public.domains(id) on delete set null,
  add column if not exists invited_by uuid
    references public.profiles(id) on delete set null,
  add column if not exists accepted_at timestamptz
    default now(),
  add column if not exists is_active boolean
    not null default true;

alter table public.family_members
  drop constraint if exists family_members_scope_check;

alter table public.family_members
  add constraint family_members_scope_check
  check (
    (
      membership_scope = 'kingdom'
      and domain_id is null
    )
    or
    (
      membership_scope = 'domain'
      and domain_id is not null
    )
  );

create table if not exists public.family_invitations (
  id uuid primary key default gen_random_uuid(),

  family_id uuid not null
    references public.families(id) on delete cascade,

  domain_id uuid
    references public.domains(id) on delete cascade,

  invited_by uuid not null
    references public.profiles(id),

  email text not null,

  role family_role not null default 'adventurer',

  membership_scope membership_scope
    not null default 'kingdom',

  token uuid not null
    default gen_random_uuid()
    unique,

  status invitation_status
    not null default 'pending',

  expires_at timestamptz
    not null default (now() + interval '7 days'),

  accepted_by uuid
    references public.profiles(id) on delete set null,

  accepted_at timestamptz,

  created_at timestamptz
    not null default now(),

  constraint family_invitations_role_check
    check (role in ('guardian', 'adventurer', 'mercenary')),

  constraint family_invitations_scope_check
    check (
      (
        membership_scope = 'kingdom'
        and domain_id is null
      )
      or
      (
        membership_scope = 'domain'
        and domain_id is not null
      )
    )
);

create index if not exists family_invitations_family_idx
  on public.family_invitations(family_id);

create index if not exists family_invitations_email_idx
  on public.family_invitations(lower(email));

create index if not exists family_invitations_token_idx
  on public.family_invitations(token);

create index if not exists family_members_domain_idx
  on public.family_members(domain_id);

alter table public.family_invitations enable row level security;