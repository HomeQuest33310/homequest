-- HomeQuest
-- Migration 0006 - Create kingdom RPC
--
-- Goal:
-- Create a complete first kingdom atomically from Flutter:
-- - family
-- - first guardian membership
-- - primary domain
-- - first chronicle
--
-- This avoids temporary RLS deadlocks during onboarding.

create or replace function public.create_profile_if_needed()
returns public.profiles
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_display_name text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_user_id;

  if found then
    return v_profile;
  end if;

  v_display_name := coalesce(
    nullif(auth.jwt() -> 'user_metadata' ->> 'display_name', ''),
    nullif(auth.jwt() ->> 'email', ''),
    'Aventurier'
  );

  insert into public.profiles (id, display_name, avatar_key)
  values (v_user_id, v_display_name, 'default_adventurer')
  returning * into v_profile;

  return v_profile;
end;
$$;

create or replace function public.create_kingdom(
  p_family_name text,
  p_kingdom_name text,
  p_primary_domain_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_family public.families%rowtype;
  v_domain_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if nullif(trim(p_family_name), '') is null then
    raise exception 'Family name is required';
  end if;

  if nullif(trim(p_kingdom_name), '') is null then
    raise exception 'Kingdom name is required';
  end if;

  if nullif(trim(p_primary_domain_name), '') is null then
    raise exception 'Primary domain name is required';
  end if;

  perform public.create_profile_if_needed();

  insert into public.families (name, kingdom_name, owner_id)
  values (trim(p_family_name), trim(p_kingdom_name), v_user_id)
  returning * into v_family;

  insert into public.family_members (family_id, user_id, role)
  values (v_family.id, v_user_id, 'guardian');

  insert into public.domains (
    family_id,
    name,
    domain_kind,
    icon,
    description,
    is_primary
  ) values (
    v_family.id,
    trim(p_primary_domain_name),
    'home',
    'home',
    'Le premier domaine du royaume.',
    true
  ) returning id into v_domain_id;

  insert into public.chronicles (family_id, type, title, body)
  values (
    v_family.id,
    'kingdom_created',
    'Le royaume est né',
    'Aujourd''hui, le royaume ' || trim(p_kingdom_name) || ' ouvre ses portes. Le domaine ' || trim(p_primary_domain_name) || ' devient le premier chapitre des Chroniques.'
  );

  return to_jsonb(v_family) || jsonb_build_object('primary_domain_id', v_domain_id);
end;
$$;

grant execute on function public.create_profile_if_needed() to authenticated;
grant execute on function public.create_kingdom(text, text, text) to authenticated;
