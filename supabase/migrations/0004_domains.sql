-- ==========================================================
-- HomeQuest
-- Migration 0004 - Domains
-- ==========================================================

-- ----------------------------------------------------------
-- Domain kind
-- ----------------------------------------------------------

create type domain_kind as enum (
    'home',
    'vacation',
    'grandparent',
    'camp',
    'custom'
);

-- ----------------------------------------------------------
-- Domains
-- ----------------------------------------------------------

create table if not exists public.domains (

    id uuid primary key default gen_random_uuid(),

    family_id uuid not null
        references public.families(id)
        on delete cascade,

    -- Visible name
    name text not null,

    -- Functional type
    domain_kind domain_kind not null default 'home',

    -- Material icon name
    icon text not null default 'home',

    -- Optional description
    description text,

    -- Main domain of the family
    is_primary boolean not null default false,

    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- ----------------------------------------------------------
-- Indexes
-- ----------------------------------------------------------

create index if not exists idx_domains_family
on public.domains(family_id);

create index if not exists idx_domains_primary
on public.domains(is_primary);

-- ----------------------------------------------------------
-- Quest relation
-- ----------------------------------------------------------

alter table public.quests
add column if not exists domain_id uuid
references public.domains(id)
on delete set null;

create index if not exists idx_quests_domain
on public.quests(domain_id);

-- ----------------------------------------------------------
-- Automatic update timestamp
-- ----------------------------------------------------------

create trigger set_domains_updated_at
before update on public.domains
for each row
execute procedure public.handle_updated_at();

-- ==========================================================
-- End migration
-- ==========================================================