begin;

create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(30);

select has_table('public', 'families', 'families table exists');
select has_table('public', 'family_members', 'family members table exists');
select has_table('public', 'quests', 'quests table exists');
select has_table('public', 'quest_assignments', 'quest assignments table exists');
select has_table('public', 'quest_completions', 'quest completions table exists');
select has_table('public', 'reward_suggestions', 'reward suggestions table exists');
select has_table('public', 'kingdom_resources', 'kingdom resources table exists');
select has_table('public', 'kingdom_buildings', 'kingdom buildings table exists');

select has_column(
  'public',
  'quests',
  'available_from',
  'quests can be scheduled'
);
select has_column(
  'public',
  'reward_suggestions',
  'priority_rank',
  'collective rewards can be prioritised'
);
select has_column(
  'public',
  'kingdom_resources',
  'crystals',
  'kingdom resources include crystals'
);
select has_column(
  'public',
  'family_members',
  'role',
  'family members keep an explicit role'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.families'::regclass),
  'families has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.family_members'::regclass
  ),
  'family_members has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.quests'::regclass),
  'quests has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.quest_assignments'::regclass
  ),
  'quest_assignments has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.quest_completions'::regclass
  ),
  'quest_completions has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.reward_suggestions'::regclass
  ),
  'reward_suggestions has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.kingdom_resources'::regclass
  ),
  'kingdom_resources has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.kingdom_buildings'::regclass
  ),
  'kingdom_buildings has RLS enabled'
);

select has_function(
  'public',
  'homequest_quest_is_available_for_member',
  array['uuid', 'uuid'],
  'member-specific recurring availability function exists'
);
select has_function(
  'public',
  'self_assign_quest',
  array['uuid'],
  'self assignment function exists'
);
select has_function(
  'public',
  'leave_quest',
  array['uuid'],
  'leave quest function exists'
);
select has_function(
  'public',
  'reorder_collective_rewards',
  array['uuid', 'uuid[]'],
  'collective reward ordering function exists'
);
select has_function(
  'public',
  'start_kingdom_construction',
  array['uuid', 'text'],
  'kingdom construction function exists'
);
select has_function(
  'public',
  'purchase_profile_avatar',
  array['uuid', 'text'],
  'profile avatar purchase function exists'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.self_assign_quest(uuid)',
    'execute'
  ),
  'authenticated players can self-assign quests'
);
select ok(
  not has_function_privilege('anon', 'public.self_assign_quest(uuid)', 'execute'),
  'anonymous users cannot self-assign quests'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.reorder_collective_rewards(uuid,uuid[])',
    'execute'
  ),
  'authenticated guardians can call reward ordering'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.reorder_collective_rewards(uuid,uuid[])',
    'execute'
  ),
  'anonymous users cannot call reward ordering'
);

select * from finish();

rollback;
