-- HomeQuest v0.8.0-alpha
-- Heroic boss bestiary, guardian creation and custom boss metadata.

alter table public.bosses
  add column if not exists emoji text not null default '🐉',
  add column if not exists element text not null default 'Neutre',
  add column if not exists domain_label text not null default 'Royaume',
  add column if not exists description text not null default '',
  add column if not exists difficulty integer not null default 3,
  add column if not exists required_level integer not null default 1,
  add column if not exists xp_reward integer not null default 0,
  add column if not exists special_item text not null default '',
  add column if not exists skill_rewards jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'bosses_gameplay_values_check'
      and conrelid = 'public.bosses'::regclass
  ) then
    alter table public.bosses add constraint bosses_gameplay_values_check
      check (
        max_hp > 0 and current_hp >= 0 and current_hp <= max_hp
        and difficulty between 1 and 5
        and required_level >= 1 and xp_reward >= 0
        and jsonb_typeof(skill_rewards) = 'array'
      );
  end if;
end;
$$;

create unique index if not exists bosses_one_active_per_family_idx
on public.bosses (family_id)
where status = 'active';

insert into public.skills (id, name, icon, description)
values
  ('combat', 'Art de la Lame', '⚔️', 'Maîtrise du combat direct et des techniques martiales.'),
  ('defense', 'Rempart d’Adamant', '🛡️', 'Protection de la guilde et résistance aux assauts.'),
  ('precision', 'Œil du Faucon', '🎯', 'Exactitude, concentration et coups décisifs.'),
  ('cooperation', 'Serment de la Guilde', '👥', 'Coordination et entraide pendant les défis collectifs.'),
  ('elemental_mastery', 'Souveraineté Élémentaire', '🔥', 'Contrôle et compréhension des forces élémentaires.'),
  ('resilience', 'Cœur Inébranlable', '⏳', 'Persévérance face aux épreuves les plus longues.'),
  ('power', 'Fureur du Colosse', '💪', 'Puissance brute mobilisée contre les adversaires majeurs.'),
  ('combat_agility', 'Danse du Zéphyr', '🏃', 'Esquive, mobilité et rapidité au combat.'),
  ('tactics', 'Stratagème Royal', '🧠', 'Planification et adaptation aux mécaniques du boss.'),
  ('magic_mastery', 'Arcane Suprême', '✨', 'Maîtrise des pouvoirs et phénomènes magiques.')
on conflict (id) do update set
  name = excluded.name,
  icon = excluded.icon,
  description = excluded.description;

create or replace function public.list_family_bosses(p_family_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.is_family_member(p_family_id) then
    raise exception 'Active family membership required';
  end if;

  select coalesce(jsonb_agg(row_data order by
    case row_data->>'status' when 'active' then 0 else 1 end,
    row_data->>'created_at' desc), '[]'::jsonb)
  into v_result
  from (
    select to_jsonb(b) || jsonb_build_object(
      'skill_rewards', coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', skill.id,
          'name', skill.name,
          'icon', skill.icon,
          'points', (reward->>'points')::integer
        ) order by skill.name)
        from jsonb_array_elements(b.skill_rewards) reward
        join public.skills skill on skill.id = reward->>'skill_id'
      ), '[]'::jsonb)
    ) row_data
    from public.bosses b
    where b.family_id = p_family_id
  ) boss_rows;
  return v_result;
end;
$$;

create or replace function public.create_family_boss(
  p_family_id uuid,
  p_name text,
  p_emoji text,
  p_element text,
  p_domain_label text,
  p_description text,
  p_max_hp integer,
  p_difficulty integer,
  p_required_level integer,
  p_xp_reward integer,
  p_special_item text,
  p_skill_rewards jsonb,
  p_replace_active boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_boss public.bosses%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can create bosses';
  end if;
  if nullif(trim(p_name), '') is null
     or nullif(trim(p_emoji), '') is null
     or nullif(trim(p_element), '') is null
     or nullif(trim(p_domain_label), '') is null then
    raise exception 'Boss name, emoji, element and domain are required';
  end if;
  if p_max_hp <= 0 or p_difficulty not between 1 and 5
     or p_required_level < 1 or p_xp_reward < 0 then
    raise exception 'Invalid boss gameplay values';
  end if;
  if jsonb_typeof(p_skill_rewards) <> 'array'
     or jsonb_array_length(p_skill_rewards) not between 2 and 6
     or (select count(distinct reward->>'skill_id')
         from jsonb_array_elements(p_skill_rewards) reward)
        <> jsonb_array_length(p_skill_rewards)
     or exists (
       select 1 from jsonb_array_elements(p_skill_rewards) reward
       where not exists (
         select 1 from public.skills skill
         where skill.id = reward->>'skill_id'
       ) or coalesce((reward->>'points')::integer, 0) <= 0
     ) then
    raise exception 'A boss requires between two and six valid skills';
  end if;

  if exists (
    select 1 from public.bosses
    where family_id = p_family_id and status = 'active'
  ) then
    if not p_replace_active then
      raise exception 'An active boss already threatens this kingdom';
    end if;
    update public.bosses set status = 'expired', ends_at = now()
    where family_id = p_family_id and status = 'active';
  end if;

  insert into public.bosses (
    family_id, name, emoji, element, domain_label, description,
    max_hp, current_hp, difficulty, required_level, xp_reward,
    special_item, skill_rewards, status, starts_at
  ) values (
    p_family_id, trim(p_name), trim(p_emoji), trim(p_element),
    trim(p_domain_label), trim(coalesce(p_description, '')),
    p_max_hp, p_max_hp, p_difficulty, p_required_level, p_xp_reward,
    trim(coalesce(p_special_item, '')), p_skill_rewards, 'active', now()
  ) returning * into v_boss;

  return to_jsonb(v_boss) || jsonb_build_object(
    'skill_rewards', (
      select jsonb_agg(jsonb_build_object(
        'skill_id', skill.id, 'name', skill.name, 'icon', skill.icon,
        'points', (reward->>'points')::integer
      ) order by skill.name)
      from jsonb_array_elements(v_boss.skill_rewards) reward
      join public.skills skill on skill.id = reward->>'skill_id'
    )
  );
end;
$$;

create or replace function public.retire_family_boss(p_boss_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_family_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select family_id into v_family_id from public.bosses where id = p_boss_id;
  if v_family_id is null then raise exception 'Boss not found'; end if;
  if not public.is_family_guardian(v_family_id) then
    raise exception 'Only guardians can retire bosses';
  end if;
  update public.bosses set status = 'expired', ends_at = now()
  where id = p_boss_id and status = 'active';
end;
$$;

revoke all on function public.list_family_bosses(uuid) from public, anon;
revoke all on function public.create_family_boss(
  uuid, text, text, text, text, text, integer, integer, integer,
  integer, text, jsonb, boolean
) from public, anon;
revoke all on function public.retire_family_boss(uuid) from public, anon;

grant execute on function public.list_family_bosses(uuid) to authenticated;
grant execute on function public.create_family_boss(
  uuid, text, text, text, text, text, integer, integer, integer,
  integer, text, jsonb, boolean
) to authenticated;
grant execute on function public.retire_family_boss(uuid) to authenticated;

notify pgrst, 'reload schema';
