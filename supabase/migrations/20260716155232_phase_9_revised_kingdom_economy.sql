-- HomeQuest Phase 9 revised kingdom economy.
-- Gold remains personal. Wood, stone, provisions, crystals and boss items
-- belong to the whole family kingdom.

alter table public.quests
  add column if not exists catalog_id integer check (catalog_id > 0);

create index if not exists quests_catalog_id_idx
  on public.quests(catalog_id)
  where catalog_id is not null;

create or replace function public.attach_voluntary_quest_catalog_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.catalog_id is null then
    select request.catalog_id
    into new.catalog_id
    from public.voluntary_quest_requests request
    where request.family_id = new.family_id
      and request.kingdom_id = new.kingdom_id
      and request.status = 'pending'
      and request.title = new.title
      and request.real_task = new.real_task
    order by request.created_at desc
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists quests_attach_voluntary_catalog_id
  on public.quests;
create trigger quests_attach_voluntary_catalog_id
before insert on public.quests
for each row
execute function public.attach_voluntary_quest_catalog_id();

create table if not exists public.kingdom_building_catalog (
  building_key text primary key,
  name text not null,
  emoji text not null,
  category text not null check (
    category in ('wood', 'stone', 'major', 'production')
  ),
  tier integer not null check (tier between 1 and 3),
  description text not null,
  bonus_description text not null,
  wood_cost integer not null default 0 check (wood_cost >= 0),
  stone_cost integer not null default 0 check (stone_cost >= 0),
  provisions_cost integer not null default 0 check (provisions_cost >= 0),
  crystals_cost integer not null default 0 check (crystals_cost >= 0),
  boss_items_cost integer not null default 0 check (boss_items_cost >= 0),
  tier_three_items_cost integer not null default 0
    check (tier_three_items_cost >= 0),
  upgrade_wood_cost integer not null default 0 check (upgrade_wood_cost >= 0),
  upgrade_stone_cost integer not null default 0 check (upgrade_stone_cost >= 0),
  upgrade_provisions_cost integer not null default 0
    check (upgrade_provisions_cost >= 0),
  upgrade_crystals_cost integer not null default 5
    check (upgrade_crystals_cost >= 0),
  build_hours integer not null check (build_hours between 1 and 168),
  max_level integer not null default 5 check (max_level between 1 and 5),
  sort_order integer not null
);

create table if not exists public.kingdom_buildings (
  family_id uuid not null references public.families(id) on delete cascade,
  building_key text not null
    references public.kingdom_building_catalog(building_key),
  level integer not null default 0 check (level between 0 and 5),
  target_level integer not null default 1 check (target_level between 1 and 5),
  status text not null default 'building'
    check (status in ('building', 'upgrading', 'completed')),
  started_by uuid not null references public.profiles(id),
  started_at timestamptz not null default now(),
  completes_at timestamptz not null,
  completed_at timestamptz,
  cost_paid jsonb not null default '{}'::jsonb
    check (jsonb_typeof(cost_paid) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (family_id, building_key)
);

create index if not exists kingdom_buildings_family_status_idx
  on public.kingdom_buildings(family_id, status, completes_at);

create table if not exists public.kingdom_boss_items (
  family_id uuid not null references public.families(id) on delete cascade,
  item_key text not null,
  name text not null,
  emoji text not null,
  tier integer not null check (tier between 1 and 5),
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (family_id, item_key)
);

create table if not exists public.kingdom_boss_drop_events (
  boss_id uuid primary key references public.bosses(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  crystals integer not null check (crystals >= 0),
  item_key text not null,
  item_name text not null,
  item_emoji text not null,
  item_tier integer not null check (item_tier between 1 and 5),
  created_at timestamptz not null default now()
);

create index if not exists kingdom_boss_drop_events_family_created_idx
  on public.kingdom_boss_drop_events(family_id, created_at desc);

create table if not exists public.kingdom_market_conversions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  converted_by uuid not null references public.profiles(id),
  resource_key text not null
    check (resource_key in ('wood', 'stone', 'provisions')),
  crystals_spent integer not null check (crystals_spent > 0),
  resource_received integer not null check (resource_received > 0),
  created_at timestamptz not null default now()
);

create index if not exists kingdom_market_conversions_family_created_idx
  on public.kingdom_market_conversions(family_id, created_at desc);

create table if not exists public.kingdom_production_state (
  family_id uuid primary key references public.families(id) on delete cascade,
  last_claim_on date not null default current_date,
  updated_at timestamptz not null default now()
);

alter table public.kingdom_building_catalog enable row level security;
alter table public.kingdom_buildings enable row level security;
alter table public.kingdom_boss_items enable row level security;
alter table public.kingdom_boss_drop_events enable row level security;
alter table public.kingdom_market_conversions enable row level security;
alter table public.kingdom_production_state enable row level security;

revoke all on table public.kingdom_building_catalog from anon, authenticated;
revoke all on table public.kingdom_buildings from anon, authenticated;
revoke all on table public.kingdom_boss_items from anon, authenticated;
revoke all on table public.kingdom_boss_drop_events from anon, authenticated;
revoke all on table public.kingdom_market_conversions
  from anon, authenticated;
revoke all on table public.kingdom_production_state from anon, authenticated;

grant select on table public.kingdom_building_catalog to authenticated;
grant select on table public.kingdom_buildings to authenticated;
grant select on table public.kingdom_boss_items to authenticated;
grant select on table public.kingdom_boss_drop_events to authenticated;
grant select on table public.kingdom_market_conversions to authenticated;

drop policy if exists "Authenticated users can read building catalog"
  on public.kingdom_building_catalog;
create policy "Authenticated users can read building catalog"
  on public.kingdom_building_catalog
  for select
  to authenticated
  using ((select auth.uid()) is not null);

drop policy if exists "Members can read kingdom buildings"
  on public.kingdom_buildings;
create policy "Members can read kingdom buildings"
  on public.kingdom_buildings
  for select
  to authenticated
  using ((select public.is_family_member(family_id)));

drop policy if exists "Members can read kingdom boss items"
  on public.kingdom_boss_items;
create policy "Members can read kingdom boss items"
  on public.kingdom_boss_items
  for select
  to authenticated
  using ((select public.is_family_member(family_id)));

drop policy if exists "Members can read kingdom boss drops"
  on public.kingdom_boss_drop_events;
create policy "Members can read kingdom boss drops"
  on public.kingdom_boss_drop_events
  for select
  to authenticated
  using ((select public.is_family_member(family_id)));

drop policy if exists "Members can read kingdom market history"
  on public.kingdom_market_conversions;
create policy "Members can read kingdom market history"
  on public.kingdom_market_conversions
  for select
  to authenticated
  using ((select public.is_family_member(family_id)));

insert into public.kingdom_building_catalog (
  building_key, name, emoji, category, tier, description, bonus_description,
  wood_cost, stone_cost, provisions_cost, crystals_cost,
  boss_items_cost, tier_three_items_cost,
  upgrade_wood_cost, upgrade_stone_cost, upgrade_provisions_cost,
  upgrade_crystals_cost, build_hours, max_level, sort_order
)
values
  ('town_hall', 'Mairie', '🏛️', 'wood', 1,
   'Le centre administratif du Royaume.',
   '+10% XP de groupe et +5% de ressources.',
   500, 100, 0, 0, 0, 0, 300, 50, 0, 0, 8, 5, 10),
  ('warehouse', 'Entrepôt', '🧰', 'wood', 1,
   'Une réserve organisée pour les richesses collectives.',
   '+25% de capacité de stockage.',
   400, 50, 0, 0, 0, 0, 250, 25, 0, 0, 8, 5, 20),
  ('market', 'Marché', '🏪', 'wood', 1,
   'Le cœur des échanges du Royaume.',
   'Débloque les conversions de cristaux en ressources.',
   300, 75, 0, 0, 0, 0, 200, 50, 0, 0, 8, 5, 30),
  ('fortress', 'Forteresse', '🏰', 'stone', 1,
   'Une enceinte solide qui protège les habitants.',
   '+20% de défense du Royaume.',
   200, 500, 0, 0, 0, 0, 150, 300, 0, 0, 8, 5, 40),
  ('granary', 'Grenier', '🌾', 'stone', 1,
   'Une réserve sûre pour les provisions.',
   '+20% de stockage de provisions.',
   150, 400, 0, 0, 0, 0, 100, 200, 0, 0, 8, 5, 50),
  ('treasury', 'Trésorerie', '🏦', 'stone', 1,
   'Un coffre collectif pour les ressources rares.',
   '+10% de limite de stockage des cristaux.',
   180, 450, 0, 0, 0, 0, 120, 250, 0, 0, 8, 5, 60),
  ('farm', 'Ferme du Royaume', '🌾', 'production', 1,
   'Des terres nourricières entretenues par toute la famille.',
   'Produit 15 provisions par jour, jusqu’à 50 au niveau 5.',
   0, 0, 200, 0, 0, 0, 0, 0, 300, 5, 8, 5, 70),
  ('carpentry', 'Atelier de Menuiserie', '🪚', 'wood', 2,
   'Transforme le bois brut en matériaux de qualité.',
   '+30% d’efficacité pour le bois.',
   600, 200, 0, 0, 0, 0, 0, 0, 0, 5, 24, 5, 80),
  ('light_forge', 'Forge Légère', '⚒️', 'wood', 2,
   'Combine le bois et la pierre pour fabriquer des outils.',
   'Débloque les outils du Royaume.',
   700, 250, 0, 0, 0, 0, 0, 0, 0, 5, 24, 5, 90),
  ('alchemy_lab', 'Laboratoire d’Alchimie', '⚗️', 'wood', 2,
   'Un atelier de potions et de remèdes.',
   'Débloque les recettes utilisant provisions et bois.',
   800, 300, 0, 0, 0, 0, 0, 0, 0, 5, 24, 5, 100),
  ('amphitheater', 'Amphithéâtre', '🎭', 'stone', 2,
   'Un lieu pour les événements communautaires.',
   '+15% de synergie familiale pendant les événements.',
   300, 700, 0, 0, 0, 0, 0, 0, 0, 5, 24, 5, 110),
  ('health_temple', 'Temple de Santé', '🏥', 'stone', 2,
   'Un sanctuaire consacré au bien-être et au sport.',
   '+10% XP Sport et quête Champion Olympique.',
   400, 900, 0, 5, 0, 0, 0, 0, 0, 5, 24, 5, 120),
  ('magic_academy', 'Académie de Magie', '🧙', 'major', 2,
   'Le premier lieu d’apprentissage des classes héroïques.',
   'Débloque les classes spécialisées.',
   600, 200, 0, 10, 0, 0, 0, 0, 0, 5, 24, 5, 130),
  ('university', 'Académie Université', '🎓', 'stone', 2,
   'Un centre de savoir avancé.',
   '+30% de bonus de classe.',
   500, 1000, 0, 10, 0, 0, 0, 0, 0, 5, 24, 5, 140),
  ('military_barracks', 'Caserne Militaire', '🛡️', 'major', 2,
   'Le terrain d’entraînement des défenseurs du Royaume.',
   '+30% de dégâts pendant les raids de boss.',
   800, 400, 0, 15, 0, 0, 0, 0, 0, 5, 24, 5, 150),
  ('wooden_palace', 'Palais de Bois', '🏯', 'wood', 3,
   'Une demeure royale sculptée par les héros.',
   '+50% de synergie visuelle et statues des héros.',
   2000, 500, 0, 0, 0, 0, 0, 0, 0, 5, 72, 5, 160),
  ('magical_forest', 'Forêt Magique', '🌳', 'major', 3,
   'Une forêt enchantée qui protège le Royaume.',
   'Produit automatiquement 10 bois par jour.',
   1500, 400, 0, 20, 0, 0, 0, 0, 0, 5, 72, 5, 170),
  ('royal_citadel', 'Citadelle Royale', '👑', 'stone', 3,
   'Le symbole d’un Royaume arrivé à maturité.',
   '+100% de synergie familiale et bannière royale.',
   1000, 3000, 0, 20, 0, 0, 0, 0, 0, 5, 72, 5, 180),
  ('observatory', 'Observatoire', '🔭', 'stone', 3,
   'Permet d’observer les terres lointaines.',
   'Débloque les explorations avancées.',
   600, 2000, 0, 10, 5, 0, 0, 0, 0, 5, 72, 5, 190),
  ('dragon_lair', 'Repaire du Dragon', '🐉', 'major', 3,
   'Un sanctuaire construit grâce aux trophées des boss.',
   'Débloque l’invocation mensuelle de CHAOSDRAKUL.',
   2000, 1000, 0, 30, 5, 0, 0, 0, 0, 5, 72, 5, 200),
  ('celestial_tower', 'Tour Céleste', '🌌', 'major', 3,
   'Le chantier ultime du Royaume.',
   'Débloque le niveau 6 des compétences et le mode Cosmique.',
   2000, 2500, 0, 50, 10, 5, 0, 0, 0, 5, 72, 5, 210)
on conflict (building_key) do update set
  name = excluded.name,
  emoji = excluded.emoji,
  category = excluded.category,
  tier = excluded.tier,
  description = excluded.description,
  bonus_description = excluded.bonus_description,
  wood_cost = excluded.wood_cost,
  stone_cost = excluded.stone_cost,
  provisions_cost = excluded.provisions_cost,
  crystals_cost = excluded.crystals_cost,
  boss_items_cost = excluded.boss_items_cost,
  tier_three_items_cost = excluded.tier_three_items_cost,
  upgrade_wood_cost = excluded.upgrade_wood_cost,
  upgrade_stone_cost = excluded.upgrade_stone_cost,
  upgrade_provisions_cost = excluded.upgrade_provisions_cost,
  upgrade_crystals_cost = excluded.upgrade_crystals_cost,
  build_hours = excluded.build_hours,
  max_level = excluded.max_level,
  sort_order = excluded.sort_order;

create or replace function public.complete_kingdom_constructions(
  p_family_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_family_member(p_family_id) then
    raise exception 'Active family membership required';
  end if;

  update public.kingdom_buildings
  set level = target_level,
      status = 'completed',
      completed_at = now(),
      updated_at = now()
  where family_id = p_family_id
    and status in ('building', 'upgrading')
    and completes_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.list_kingdom_buildings(
  p_family_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_family_member(p_family_id) then
    raise exception 'Active family membership required';
  end if;

  perform public.complete_kingdom_constructions(p_family_id);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'building_key', catalog.building_key,
      'name', catalog.name,
      'emoji', catalog.emoji,
      'category', catalog.category,
      'tier', catalog.tier,
      'description', catalog.description,
      'bonus_description', catalog.bonus_description,
      'wood_cost', case when coalesce(building.level, 0) = 0
        then catalog.wood_cost else catalog.upgrade_wood_cost end,
      'stone_cost', case when coalesce(building.level, 0) = 0
        then catalog.stone_cost else catalog.upgrade_stone_cost end,
      'provisions_cost', case
        when catalog.building_key = 'farm'
             and coalesce(building.level, 0) = 4 then 600
        when coalesce(building.level, 0) = 0
          then catalog.provisions_cost
        else catalog.upgrade_provisions_cost
      end,
      'crystals_cost', case
        when catalog.building_key = 'farm'
             and coalesce(building.level, 0) = 4 then 20
        when coalesce(building.level, 0) = 0
          then catalog.crystals_cost
        else catalog.upgrade_crystals_cost
      end,
      'boss_items_cost', case when coalesce(building.level, 0) = 0
        then catalog.boss_items_cost else 0 end,
      'tier_three_items_cost', case when coalesce(building.level, 0) = 0
        then catalog.tier_three_items_cost else 0 end,
      'build_hours', catalog.build_hours,
      'max_level', catalog.max_level,
      'level', coalesce(building.level, 0),
      'target_level', coalesce(building.target_level, 1),
      'status', coalesce(building.status, 'available'),
      'started_at', building.started_at,
      'completes_at', building.completes_at,
      'completed_at', building.completed_at
    ) order by catalog.sort_order
  ), '[]'::jsonb)
  into v_result
  from public.kingdom_building_catalog catalog
  left join public.kingdom_buildings building
    on building.family_id = p_family_id
   and building.building_key = catalog.building_key;

  return v_result;
end;
$$;

create or replace function public.consume_kingdom_boss_items(
  p_family_id uuid,
  p_total integer,
  p_tier_three_minimum integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_available integer;
  v_tier_three_available integer;
  v_remaining integer := p_total;
  v_required_tier_three integer := p_tier_three_minimum;
  v_take integer;
  v_item record;
begin
  if p_total <= 0 then return; end if;

  perform 1
  from public.kingdom_boss_items
  where family_id = p_family_id
  for update;

  select coalesce(sum(quantity), 0),
         coalesce(sum(quantity) filter (where tier >= 3), 0)
  into v_available, v_tier_three_available
  from public.kingdom_boss_items
  where family_id = p_family_id;

  if v_available < p_total then
    raise exception 'Not enough boss items';
  end if;
  if v_tier_three_available < p_tier_three_minimum then
    raise exception 'Not enough tier 3 boss items';
  end if;

  for v_item in
    select item_key, quantity
    from public.kingdom_boss_items
    where family_id = p_family_id
      and tier >= 3
      and quantity > 0
    order by tier, item_key
    for update
  loop
    exit when v_required_tier_three = 0;
    v_take := least(v_item.quantity, v_required_tier_three);
    update public.kingdom_boss_items
    set quantity = quantity - v_take,
        updated_at = now()
    where family_id = p_family_id and item_key = v_item.item_key;
    v_required_tier_three := v_required_tier_three - v_take;
    v_remaining := v_remaining - v_take;
  end loop;

  for v_item in
    select item_key, quantity
    from public.kingdom_boss_items
    where family_id = p_family_id
      and quantity > 0
    order by tier, item_key
    for update
  loop
    exit when v_remaining = 0;
    v_take := least(v_item.quantity, v_remaining);
    update public.kingdom_boss_items
    set quantity = quantity - v_take,
        updated_at = now()
    where family_id = p_family_id and item_key = v_item.item_key;
    v_remaining := v_remaining - v_take;
  end loop;
end;
$$;

create or replace function public.start_kingdom_construction(
  p_family_id uuid,
  p_building_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_catalog public.kingdom_building_catalog%rowtype;
  v_building public.kingdom_buildings%rowtype;
  v_resources public.kingdom_resources%rowtype;
  v_level integer;
  v_target_level integer;
  v_wood integer;
  v_stone integer;
  v_provisions integer;
  v_crystals integer;
  v_boss_items integer;
  v_tier_three_items integer;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can start a construction';
  end if;

  -- Serialize economy mutations for one family. This prevents two simultaneous
  -- requests from paying twice for the same first-level construction.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('kingdom_economy:' || p_family_id::text, 0)
  );

  select * into v_catalog
  from public.kingdom_building_catalog
  where building_key = p_building_key;
  if v_catalog.building_key is null then
    raise exception 'Building not found';
  end if;

  perform public.complete_kingdom_constructions(p_family_id);

  select * into v_building
  from public.kingdom_buildings
  where family_id = p_family_id
    and building_key = p_building_key
  for update;

  v_level := coalesce(v_building.level, 0);
  if v_building.status in ('building', 'upgrading') then
    raise exception 'This construction is already in progress';
  end if;
  if v_level >= v_catalog.max_level then
    raise exception 'This building has reached its maximum level';
  end if;

  v_target_level := v_level + 1;
  if v_level = 0 then
    v_wood := v_catalog.wood_cost;
    v_stone := v_catalog.stone_cost;
    v_provisions := v_catalog.provisions_cost;
    v_crystals := v_catalog.crystals_cost;
    v_boss_items := v_catalog.boss_items_cost;
    v_tier_three_items := v_catalog.tier_three_items_cost;
    v_status := 'building';
  else
    v_wood := v_catalog.upgrade_wood_cost;
    v_stone := v_catalog.upgrade_stone_cost;
    v_provisions := v_catalog.upgrade_provisions_cost;
    v_crystals := v_catalog.upgrade_crystals_cost;
    v_boss_items := 0;
    v_tier_three_items := 0;
    v_status := 'upgrading';
    if p_building_key = 'farm' and v_target_level = 5 then
      v_provisions := 600;
      v_crystals := 20;
    end if;
  end if;

  insert into public.kingdom_resources (family_id)
  values (p_family_id)
  on conflict (family_id) do nothing;

  select * into v_resources
  from public.kingdom_resources
  where family_id = p_family_id
  for update;

  if v_resources.wood < v_wood
     or v_resources.stone < v_stone
     or v_resources.provisions < v_provisions
     or v_resources.crystals < v_crystals then
    raise exception 'Not enough kingdom resources';
  end if;

  perform public.consume_kingdom_boss_items(
    p_family_id, v_boss_items, v_tier_three_items
  );

  update public.kingdom_resources
  set wood = wood - v_wood,
      stone = stone - v_stone,
      provisions = provisions - v_provisions,
      crystals = crystals - v_crystals,
      updated_at = now()
  where family_id = p_family_id;

  insert into public.kingdom_buildings (
    family_id, building_key, level, target_level, status,
    started_by, started_at, completes_at, completed_at,
    cost_paid, updated_at
  ) values (
    p_family_id, p_building_key, v_level, v_target_level, v_status,
    auth.uid(), now(),
    now() + make_interval(hours => v_catalog.build_hours),
    null,
    jsonb_build_object(
      'wood', v_wood,
      'stone', v_stone,
      'provisions', v_provisions,
      'crystals', v_crystals,
      'boss_items', v_boss_items
    ),
    now()
  )
  on conflict (family_id, building_key) do update set
    target_level = excluded.target_level,
    status = excluded.status,
    started_by = excluded.started_by,
    started_at = excluded.started_at,
    completes_at = excluded.completes_at,
    completed_at = null,
    cost_paid = excluded.cost_paid,
    updated_at = now();

  select to_jsonb(building) into v_result
  from public.kingdom_buildings building
  where family_id = p_family_id
    and building_key = p_building_key;
  return v_result;
end;
$$;

create or replace function public.convert_kingdom_crystals(
  p_family_id uuid,
  p_resource_key text,
  p_crystals integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_resources public.kingdom_resources%rowtype;
  v_crystals_today integer;
  v_resource_today integer;
  v_received integer;
  v_market_ready boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_family_guardian(p_family_id) then
    raise exception 'Only guardians can use the kingdom market';
  end if;

  -- Daily limits and the crystal balance must be checked as one serialized
  -- operation for each family.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('kingdom_economy:' || p_family_id::text, 0)
  );

  if p_resource_key not in ('wood', 'stone', 'provisions')
     or p_crystals not between 1 and 50 then
    raise exception 'Invalid market conversion';
  end if;

  select exists (
    select 1 from public.kingdom_buildings
    where family_id = p_family_id
      and building_key = 'market'
      and status = 'completed'
      and level >= 1
  ) into v_market_ready;
  if not v_market_ready then
    raise exception 'The market must be built first';
  end if;

  select coalesce(sum(crystals_spent), 0),
         coalesce(sum(resource_received)
           filter (where resource_key = p_resource_key), 0)
  into v_crystals_today, v_resource_today
  from public.kingdom_market_conversions
  where family_id = p_family_id
    and created_at >= date_trunc('day', now());

  if v_crystals_today + p_crystals > 50 then
    raise exception 'Daily crystal conversion limit reached';
  end if;

  v_received := case p_resource_key
    when 'wood' then p_crystals * 50
    when 'stone' then p_crystals * 30
    else p_crystals * 100
  end;

  if p_resource_key = 'wood' and v_resource_today + v_received > 100 then
    raise exception 'Daily wood purchase limit reached';
  end if;
  if p_resource_key = 'stone' and v_resource_today + v_received > 60 then
    raise exception 'Daily stone purchase limit reached';
  end if;

  select * into v_resources
  from public.kingdom_resources
  where family_id = p_family_id
  for update;
  if v_resources.crystals < p_crystals then
    raise exception 'Not enough crystals';
  end if;

  update public.kingdom_resources
  set crystals = crystals - p_crystals,
      wood = wood + case when p_resource_key = 'wood' then v_received else 0 end,
      stone = stone + case when p_resource_key = 'stone' then v_received else 0 end,
      provisions = provisions + case
        when p_resource_key = 'provisions' then v_received else 0 end,
      updated_at = now()
  where family_id = p_family_id;

  insert into public.kingdom_market_conversions (
    family_id, converted_by, resource_key,
    crystals_spent, resource_received
  ) values (
    p_family_id, auth.uid(), p_resource_key, p_crystals, v_received
  );

  return jsonb_build_object(
    'resource_key', p_resource_key,
    'crystals_spent', p_crystals,
    'resource_received', v_received
  );
end;
$$;

create or replace function public.claim_kingdom_production(
  p_family_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last_claim date;
  v_days integer;
  v_farm_level integer := 0;
  v_forest_level integer := 0;
  v_wood_gain integer := 0;
  v_provisions_gain integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_family_member(p_family_id) then
    raise exception 'Active family membership required';
  end if;

  perform public.complete_kingdom_constructions(p_family_id);

  insert into public.kingdom_production_state (family_id)
  values (p_family_id)
  on conflict (family_id) do nothing;

  select last_claim_on into v_last_claim
  from public.kingdom_production_state
  where family_id = p_family_id
  for update;

  v_days := least(greatest(current_date - v_last_claim, 0), 30);
  if v_days = 0 then
    return jsonb_build_object('days', 0, 'wood', 0, 'provisions', 0);
  end if;

  select coalesce(max(level), 0) into v_farm_level
  from public.kingdom_buildings
  where family_id = p_family_id
    and building_key = 'farm'
    and status = 'completed';

  select coalesce(max(level), 0) into v_forest_level
  from public.kingdom_buildings
  where family_id = p_family_id
    and building_key = 'magical_forest'
    and status = 'completed';

  if v_farm_level > 0 then
    v_provisions_gain := v_days * case
      when v_farm_level >= 5 then 50
      else 15 + ((v_farm_level - 1) * 5)
    end;
  end if;
  if v_forest_level > 0 then
    v_wood_gain := v_days * 10;
  end if;

  insert into public.kingdom_resources (
    family_id, wood, provisions, updated_at
  ) values (
    p_family_id, v_wood_gain, v_provisions_gain, now()
  )
  on conflict (family_id) do update set
    wood = public.kingdom_resources.wood + excluded.wood,
    provisions = public.kingdom_resources.provisions + excluded.provisions,
    updated_at = now();

  update public.kingdom_production_state
  set last_claim_on = current_date,
      updated_at = now()
  where family_id = p_family_id;

  return jsonb_build_object(
    'days', v_days,
    'wood', v_wood_gain,
    'provisions', v_provisions_gain
  );
end;
$$;

create or replace function public.grant_kingdom_boss_drop(
  p_boss_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_boss public.bosses%rowtype;
  v_name text;
  v_crystals integer;
  v_item_key text;
  v_item_name text;
  v_item_emoji text;
  v_item_tier integer;
  v_inserted uuid;
begin
  select * into v_boss
  from public.bosses
  where id = p_boss_id
    and status = 'defeated';
  if v_boss.id is null then return; end if;

  v_name := lower(trim(v_boss.name));

  if v_name like '%neo%chaosdrakul%' then
    v_crystals := 50; v_item_key := 'cosmic_essence';
    v_item_name := 'Essence Cosmique'; v_item_emoji := '⭐'; v_item_tier := 5;
  elsif v_name like '%chaosdrakul%' then
    v_crystals := 20; v_item_key := 'dragon_heart';
    v_item_name := 'Cœur de Dragon'; v_item_emoji := '🐉'; v_item_tier := 4;
  elsif v_name like '%inferno%' then
    v_crystals := 2; v_item_key := 'flame_crown';
    v_item_name := 'Couronne de Flamme'; v_item_emoji := '🔥'; v_item_tier := 1;
  elsif v_name like '%typhoon%' then
    v_crystals := 3; v_item_key := 'water_trident';
    v_item_name := 'Trident d’Eau'; v_item_emoji := '💧'; v_item_tier := 1;
  elsif v_name like '%stoneheart%' then
    v_crystals := 2; v_item_key := 'earth_gem';
    v_item_name := 'Gemme Terrestre'; v_item_emoji := '🌍'; v_item_tier := 1;
  elsif v_name like '%stormwind%' then
    v_crystals := 3; v_item_key := 'air_cape';
    v_item_name := 'Cape Aérienne'; v_item_emoji := '💨'; v_item_tier := 1;
  elsif v_name like '%luminar%' then
    v_crystals := 2; v_item_key := 'light_orb';
    v_item_name := 'Orbe de Lumière'; v_item_emoji := '✨'; v_item_tier := 1;
  elsif v_name like '%mechanomancer%' then
    v_crystals := 5; v_item_key := 'mechanical_heart';
    v_item_name := 'Cœur Mécanique'; v_item_emoji := '⚙️'; v_item_tier := 2;
  elsif v_name like '%naturalis%' then
    v_crystals := 7; v_item_key := 'forest_crown';
    v_item_name := 'Couronne Forestière'; v_item_emoji := '🌿'; v_item_tier := 2;
  elsif v_name like '%shadowborn%' then
    v_crystals := 6; v_item_key := 'shadow_cloak';
    v_item_name := 'Manteau Ombragé'; v_item_emoji := '🌑'; v_item_tier := 2;
  elsif v_name like '%tempestix%' then
    v_crystals := 10; v_item_key := 'lightning_trident';
    v_item_name := 'Trident de Foudre'; v_item_emoji := '⚡'; v_item_tier := 3;
  elsif v_name like '%frostking%' then
    v_crystals := 8; v_item_key := 'frozen_crown';
    v_item_name := 'Couronne Glacée'; v_item_emoji := '❄️'; v_item_tier := 3;
  else
    v_item_tier := greatest(1, least(3, coalesce(v_boss.difficulty, 1)));
    v_crystals := case v_item_tier when 1 then 2 when 2 then 5 else 8 end;
    v_item_key := 'boss_' || replace(v_boss.id::text, '-', '');
    v_item_name := coalesce(nullif(trim(v_boss.special_item), ''),
                            'Trophée de ' || v_boss.name);
    v_item_emoji := coalesce(nullif(trim(v_boss.emoji), ''), '🎁');
  end if;

  insert into public.kingdom_boss_drop_events (
    boss_id, family_id, crystals, item_key, item_name, item_emoji, item_tier
  ) values (
    v_boss.id, v_boss.family_id, v_crystals,
    v_item_key, v_item_name, v_item_emoji, v_item_tier
  )
  on conflict (boss_id) do nothing
  returning boss_id into v_inserted;
  if v_inserted is null then return; end if;

  insert into public.kingdom_resources (family_id, crystals, updated_at)
  values (v_boss.family_id, v_crystals, now())
  on conflict (family_id) do update set
    crystals = public.kingdom_resources.crystals + excluded.crystals,
    updated_at = now();

  insert into public.kingdom_boss_items (
    family_id, item_key, name, emoji, tier, quantity, updated_at
  ) values (
    v_boss.family_id, v_item_key, v_item_name, v_item_emoji,
    v_item_tier, 1, now()
  )
  on conflict (family_id, item_key) do update set
    quantity = public.kingdom_boss_items.quantity + 1,
    name = excluded.name,
    emoji = excluded.emoji,
    tier = excluded.tier,
    updated_at = now();
end;
$$;

create or replace function public.award_kingdom_boss_drop()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'defeated'
     and old.status is distinct from 'defeated' then
    perform public.grant_kingdom_boss_drop(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists boss_defeat_awards_kingdom_drop
  on public.bosses;
create trigger boss_defeat_awards_kingdom_drop
after update of status on public.bosses
for each row
execute function public.award_kingdom_boss_drop();

-- Revised quest allocation. Quests never grant crystals; crystals are boss
-- drops only. Exact catalog quests use the values from the Phase 9 document,
-- while custom quests use their region, title and difficulty.
create or replace function public.award_kingdom_resources()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quest public.quests%rowtype;
  v_text text;
  v_level integer;
  v_wood integer := 0;
  v_stone integer := 0;
  v_provisions integer := 0;
  v_event_id uuid;
begin
  if new.status <> 'approved' or old.status = 'approved' then
    return new;
  end if;

  select * into v_quest from public.quests where id = new.quest_id;
  if v_quest.id is null then return new; end if;

  v_level := greatest(1, least(5, coalesce(v_quest.difficulty, 1)));
  v_text := lower(concat_ws(
    ' ', v_quest.title, v_quest.real_task, v_quest.region_key, v_quest.element
  ));

  if v_quest.catalog_id between 1 and 10 then
    v_wood := greatest(1, v_level - 2);
    v_stone := greatest(1, v_level);
    v_provisions := 10 + (v_level * 4);
  elsif v_quest.catalog_id = 75 then
    v_provisions := 40;
  elsif v_quest.catalog_id = 83 then
    v_wood := 15;
  elsif v_quest.catalog_id = 84 then
    v_stone := 20;
  elsif v_quest.catalog_id between 86 and 87 then
    v_wood := 5;
    v_stone := 10;
  elsif v_quest.catalog_id = 79 then
    v_wood := 5;
  elsif v_quest.catalog_id between 80 and 82 then
    v_stone := 10;
  elsif v_quest.catalog_id = 88 then
    v_provisions := 20;
  elsif v_quest.catalog_id = 89 then
    v_provisions := 10;
  elsif v_quest.catalog_id = 90 then
    v_wood := 5;
    v_stone := 5;
    v_provisions := 15;
  elsif v_text like any (array[
    '%extérieur%', '%exterieur%', '%jardin%', '%voiture%',
    '%compost%', '%volet%'
  ]) then
    v_wood := 3 + (v_level * 2);
    v_stone := v_level;
  elsif v_text like any (array[
    '%cuisine%', '%repas%', '%culinaire%', '%vaisselle%'
  ]) then
    v_provisions := 8 + (v_level * 4);
    v_stone := case when v_text like '%vaisselle%' then 8 else v_level end;
  elsif v_text like any (array[
    '%ranger%', '%rangement%', '%organisation%', '%organisation%',
    '%chambre%', '%routine%'
  ]) then
    v_stone := 3 + (v_level * 3);
    v_provisions := v_level * 2;
  elsif v_text like any (array[
    '%sport%', '%famille%', '%communaut%', '%bonne action%'
  ]) then
    v_provisions := 5 + (v_level * 3);
    v_wood := v_level;
  else
    v_wood := v_level * 2;
    v_stone := v_level * 2;
    v_provisions := v_level * 3;
  end if;

  insert into public.kingdom_resource_events (
    family_id, completion_id, quest_element, quest_difficulty,
    wood, stone, provisions, crystals
  ) values (
    v_quest.family_id, new.id, coalesce(v_quest.element, 'Neutre'), v_level,
    v_wood, v_stone, v_provisions, 0
  )
  on conflict (completion_id) do nothing
  returning id into v_event_id;
  if v_event_id is null then return new; end if;

  insert into public.kingdom_resources (
    family_id, wood, stone, provisions, crystals, updated_at
  ) values (
    v_quest.family_id, v_wood, v_stone, v_provisions, 0, now()
  )
  on conflict (family_id) do update set
    wood = public.kingdom_resources.wood + excluded.wood,
    stone = public.kingdom_resources.stone + excluded.stone,
    provisions = public.kingdom_resources.provisions + excluded.provisions,
    updated_at = now();
  return new;
end;
$$;

create or replace function public.initialize_kingdom_economy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.kingdom_resources (family_id)
  values (new.id)
  on conflict (family_id) do nothing;

  insert into public.kingdom_production_state (family_id)
  values (new.id)
  on conflict (family_id) do nothing;
  return new;
end;
$$;

drop trigger if exists family_initializes_kingdom_economy
  on public.families;
create trigger family_initializes_kingdom_economy
after insert on public.families
for each row
execute function public.initialize_kingdom_economy();

revoke execute on function public.complete_kingdom_constructions(uuid)
  from public, anon;
revoke execute on function public.list_kingdom_buildings(uuid)
  from public, anon;
revoke execute on function public.start_kingdom_construction(uuid, text)
  from public, anon;
revoke execute on function public.convert_kingdom_crystals(uuid, text, integer)
  from public, anon;
revoke execute on function public.claim_kingdom_production(uuid)
  from public, anon;

grant execute on function public.complete_kingdom_constructions(uuid)
  to authenticated;
grant execute on function public.list_kingdom_buildings(uuid)
  to authenticated;
grant execute on function public.start_kingdom_construction(uuid, text)
  to authenticated;
grant execute on function public.convert_kingdom_crystals(uuid, text, integer)
  to authenticated;
grant execute on function public.claim_kingdom_production(uuid)
  to authenticated;

revoke execute on function public.consume_kingdom_boss_items(
  uuid, integer, integer
) from public, anon, authenticated;
revoke execute on function public.grant_kingdom_boss_drop(uuid)
  from public, anon, authenticated;
revoke execute on function public.award_kingdom_boss_drop()
  from public, anon, authenticated;
revoke execute on function public.award_kingdom_resources()
  from public, anon, authenticated;
revoke execute on function public.initialize_kingdom_economy()
  from public, anon, authenticated;
revoke execute on function public.attach_voluntary_quest_catalog_id()
  from public, anon, authenticated;

-- Preserve existing balances. Backfill one boss drop for every defeated boss,
-- guarded by the immutable boss_id event primary key.
do $$
declare v_boss record;
begin
  for v_boss in
    select id from public.bosses where status = 'defeated'
  loop
    perform public.grant_kingdom_boss_drop(v_boss.id);
  end loop;
end;
$$;

insert into public.kingdom_production_state (family_id)
select family.id from public.families family
on conflict (family_id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'kingdom_buildings'
  ) then
    alter publication supabase_realtime
      add table public.kingdom_buildings;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'kingdom_boss_items'
  ) then
    alter publication supabase_realtime
      add table public.kingdom_boss_items;
  end if;
end;
$$;

notify pgrst, 'reload schema';
