-- Voluntary quests proposed by adventurers and mercenaries from the catalog.
-- A guardian must approve the proposal, whether it is planned or already done.

create table if not exists public.voluntary_quest_requests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  kingdom_id uuid not null references public.kingdoms(id) on delete cascade,
  domain_id uuid not null references public.domains(id) on delete restrict,
  requested_by uuid not null references public.family_members(id) on delete cascade,
  requester_name text not null,
  catalog_id integer not null,
  title text not null,
  real_task text not null,
  description text,
  emoji text not null,
  element text not null,
  difficulty integer not null check (difficulty between 1 and 5),
  region_key text not null,
  xp_reward integer not null check (xp_reward between 1 and 100),
  gold_reward integer not null check (gold_reward between 0 and 100),
  boss_damage integer not null check (boss_damage between 0 and 100),
  skill_rewards jsonb not null,
  already_completed boolean not null default false,
  requester_note text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references public.family_members(id) on delete set null,
  review_note text,
  quest_id uuid references public.quests(id) on delete set null,
  completion_id uuid references public.quest_completions(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint voluntary_quest_requests_skill_rewards_check check (
    jsonb_typeof(skill_rewards) = 'array'
    and jsonb_array_length(skill_rewards) = 2
  )
);

create index if not exists voluntary_quest_requests_kingdom_status_idx
  on public.voluntary_quest_requests (kingdom_id, status, created_at desc);

create index if not exists voluntary_quest_requests_requester_idx
  on public.voluntary_quest_requests (requested_by, created_at desc);

create unique index if not exists voluntary_quest_requests_one_pending_idx
  on public.voluntary_quest_requests (kingdom_id, requested_by, catalog_id)
  where status = 'pending';

alter table public.voluntary_quest_requests enable row level security;

drop policy if exists "Kingdom members can read voluntary quest requests"
  on public.voluntary_quest_requests;

create policy "Kingdom members can read voluntary quest requests"
on public.voluntary_quest_requests
for select
to authenticated
using (public.is_kingdom_member(kingdom_id));

revoke all on table public.voluntary_quest_requests from public, anon;
grant select on table public.voluntary_quest_requests to authenticated;

create or replace function public.submit_voluntary_quest_request(
  p_kingdom_id uuid,
  p_domain_id uuid,
  p_catalog_id integer,
  p_title text,
  p_real_task text,
  p_description text,
  p_emoji text,
  p_element text,
  p_difficulty integer,
  p_region_key text,
  p_xp_reward integer,
  p_gold_reward integer,
  p_boss_damage integer,
  p_skill_rewards jsonb,
  p_already_completed boolean,
  p_requester_note text
)
returns public.voluntary_quest_requests
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_member public.family_members%rowtype;
  v_kingdom_member public.kingdom_members%rowtype;
  v_family_id uuid;
  v_request public.voluntary_quest_requests;
  v_profile_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select family_id into v_family_id
  from public.kingdoms
  where id = p_kingdom_id and archived_at is null;

  if v_family_id is null then
    raise exception 'Kingdom not found';
  end if;

  select fm.* into v_member
  from public.family_members fm
  where fm.user_id = auth.uid()
    and fm.family_id = v_family_id
    and fm.is_active
    and (fm.expires_at is null or fm.expires_at > now())
  limit 1;

  select km.* into v_kingdom_member
  from public.kingdom_members km
  where km.member_id = v_member.id
    and km.kingdom_id = p_kingdom_id
    and km.is_active
    and (km.expires_at is null or km.expires_at > now())
  limit 1;

  if v_member.id is null then
    raise exception 'You are not an active member of this kingdom';
  end if;
  if v_kingdom_member.role not in ('adventurer', 'mercenary') then
    raise exception 'Only adventurers and mercenaries can propose a voluntary quest';
  end if;
  if v_kingdom_member.role = 'mercenary'
     and v_kingdom_member.membership_scope = 'domain'
     and v_kingdom_member.domain_id is distinct from p_domain_id then
    raise exception 'This domain is outside the mercenary mission scope';
  end if;
  if not exists (
    select 1 from public.domains d
    where d.id = p_domain_id
      and d.kingdom_id = p_kingdom_id
      and d.archived_at is null
  ) then
    raise exception 'Domain does not belong to this kingdom';
  end if;
  if p_catalog_id <= 0 then
    raise exception 'A catalog quest is required';
  end if;
  if nullif(trim(p_title), '') is null
     or nullif(trim(p_real_task), '') is null
     or nullif(trim(p_emoji), '') is null
     or nullif(trim(p_element), '') is null then
    raise exception 'Quest catalog data is incomplete';
  end if;
  if p_difficulty not between 1 and 5
     or p_xp_reward not between 1 and 100
     or p_gold_reward <> p_difficulty * 5
     or p_boss_damage <> p_difficulty * 5 then
    raise exception 'Quest rewards do not match the catalog scale';
  end if;
  if jsonb_typeof(p_skill_rewards) <> 'array'
     or jsonb_array_length(p_skill_rewards) <> 2
     or (
       select count(distinct reward->>'skill_id')
       from jsonb_array_elements(p_skill_rewards) reward
     ) <> 2
     or exists (
       select 1
       from jsonb_array_elements(p_skill_rewards) reward
       where not exists (
         select 1 from public.skills skill
         where skill.id = reward->>'skill_id'
       )
       or coalesce((reward->>'xp_reward')::integer, 0) <= 0
       or coalesce((reward->>'xp_reward')::integer, 0) > 50
     ) then
    raise exception 'Exactly two valid skill rewards are required';
  end if;

  select display_name into v_profile_name
  from public.profiles where id = auth.uid();

  insert into public.voluntary_quest_requests (
    family_id, kingdom_id, domain_id, requested_by, requester_name,
    catalog_id, title, real_task, description, emoji, element, difficulty,
    region_key, xp_reward, gold_reward, boss_damage, skill_rewards,
    already_completed, requester_note
  ) values (
    v_family_id, p_kingdom_id, p_domain_id, v_member.id,
    coalesce(nullif(trim(v_profile_name), ''), 'Un héros'),
    p_catalog_id, trim(p_title), trim(p_real_task),
    nullif(trim(coalesce(p_description, '')), ''), trim(p_emoji),
    trim(p_element), p_difficulty,
    coalesce(nullif(trim(p_region_key), ''), 'custom'), p_xp_reward,
    p_gold_reward, p_boss_damage, p_skill_rewards,
    coalesce(p_already_completed, false),
    nullif(trim(coalesce(p_requester_note, '')), '')
  ) returning * into v_request;

  insert into public.guardian_notifications (
    family_id, recipient_member_id, actor_member_id, kind, title, body
  )
  select
    v_family_id,
    guardian.member_id,
    v_member.id,
    'voluntary_quest_request',
    'Nouvelle initiative héroïque',
    v_request.requester_name || case
      when v_request.already_completed then ' affirme avoir accompli « '
      else ' souhaite accomplir « '
    end || v_request.title || ' ».'
  from public.kingdom_members guardian
  where guardian.kingdom_id = p_kingdom_id
    and guardian.role = 'guardian'
    and guardian.is_active
    and (guardian.expires_at is null or guardian.expires_at > now());

  return v_request;
end;
$$;

create or replace function public.review_voluntary_quest_request(
  p_request_id uuid,
  p_approve boolean,
  p_review_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.voluntary_quest_requests%rowtype;
  v_guardian_member_id uuid;
  v_quest public.quests%rowtype;
  v_completion public.quest_completions%rowtype;
  v_reward jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_request
  from public.voluntary_quest_requests
  where id = p_request_id
  for update;

  if v_request.id is null then
    raise exception 'Voluntary quest request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'This request has already been reviewed';
  end if;
  if not public.is_kingdom_guardian(v_request.kingdom_id) then
    raise exception 'Only this kingdom''s guardians can review requests';
  end if;

  select fm.id into v_guardian_member_id
  from public.family_members fm
  join public.kingdom_members km on km.member_id = fm.id
  where fm.user_id = auth.uid()
    and fm.family_id = v_request.family_id
    and fm.is_active
    and km.kingdom_id = v_request.kingdom_id
    and km.role = 'guardian'
    and km.is_active
  limit 1;

  if not coalesce(p_approve, false) then
    update public.voluntary_quest_requests
    set status = 'rejected', reviewed_by = v_guardian_member_id,
        review_note = nullif(trim(coalesce(p_review_note, '')), ''),
        reviewed_at = now()
    where id = v_request.id
    returning * into v_request;

    return jsonb_build_object('request', to_jsonb(v_request));
  end if;

  insert into public.quests (
    family_id, kingdom_id, domain_id, created_by, title, real_task,
    description, region_key, emoji, element, difficulty, xp_reward,
    gold_reward, boss_damage, frequency, requires_approval, status
  ) values (
    v_request.family_id, v_request.kingdom_id, v_request.domain_id,
    auth.uid(), v_request.title, v_request.real_task, v_request.description,
    v_request.region_key, v_request.emoji, v_request.element,
    v_request.difficulty, v_request.xp_reward, v_request.gold_reward,
    v_request.boss_damage, 'once', true, 'active'
  ) returning * into v_quest;

  insert into public.quest_skill_rewards (quest_id, skill_id, xp_reward)
  select v_quest.id, reward->>'skill_id', (reward->>'xp_reward')::integer
  from jsonb_array_elements(v_request.skill_rewards) reward;

  insert into public.quest_assignments (quest_id, member_id)
  values (v_quest.id, v_request.requested_by)
  on conflict (quest_id, member_id) do nothing;

  if v_request.already_completed then
    insert into public.quest_completions (
      quest_id, completed_by, status, note, completed_at
    ) values (
      v_quest.id, v_request.requested_by, 'pending',
      v_request.requester_note, now()
    ) returning * into v_completion;

    v_reward := public.apply_quest_completion_rewards(
      v_completion.id, v_guardian_member_id, false
    );
  end if;

  update public.voluntary_quest_requests
  set status = 'approved', reviewed_by = v_guardian_member_id,
      review_note = nullif(trim(coalesce(p_review_note, '')), ''),
      quest_id = v_quest.id,
      completion_id = case when v_completion.id is null then null else v_completion.id end,
      reviewed_at = now()
  where id = v_request.id
  returning * into v_request;

  return jsonb_build_object(
    'request', to_jsonb(v_request),
    'quest_id', v_quest.id,
    'completion_id', v_completion.id,
    'reward', v_reward
  );
end;
$$;

revoke all on function public.submit_voluntary_quest_request(
  uuid, uuid, integer, text, text, text, text, text, integer, text,
  integer, integer, integer, jsonb, boolean, text
) from public, anon;

revoke all on function public.review_voluntary_quest_request(
  uuid, boolean, text
) from public, anon;

grant execute on function public.submit_voluntary_quest_request(
  uuid, uuid, integer, text, text, text, text, text, integer, text,
  integer, integer, integer, jsonb, boolean, text
) to authenticated;

grant execute on function public.review_voluntary_quest_request(
  uuid, boolean, text
) to authenticated;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'voluntary_quest_requests'
  ) then
    alter publication supabase_realtime
      add table public.voluntary_quest_requests;
  end if;
end;
$$;

notify pgrst, 'reload schema';
