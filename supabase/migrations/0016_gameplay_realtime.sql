-- HomeQuest v0.5.2-alpha
-- Realtime synchronization for quests, assignments, completions and rewards.

drop policy if exists "Members can read quest assignments"
on public.quest_assignments;

create policy "Members can read quest assignments"
on public.quest_assignments for select to authenticated
using (
  exists (
    select 1
    from public.quests q
    where q.id = quest_assignments.quest_id
      and public.is_family_member(q.family_id)
  )
);

drop policy if exists "Members can read quest completions"
on public.quest_completions;

create policy "Members can read quest completions"
on public.quest_completions for select to authenticated
using (
  exists (
    select 1
    from public.quests q
    where q.id = quest_completions.quest_id
      and public.is_family_member(q.family_id)
  )
);

-- Realtime checks both table privileges and RLS before delivering an event.
grant select on table
  public.quests,
  public.quest_assignments,
  public.quest_completions,
  public.family_members,
  public.member_skills,
  public.bosses,
  public.boss_damage_events,
  public.chronicles
to authenticated;

do $$
declare
  v_table_name text;
begin
  foreach v_table_name in array array[
    'quests',
    'quest_assignments',
    'quest_completions',
    'family_members',
    'member_skills',
    'bosses',
    'boss_damage_events',
    'chronicles'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        v_table_name
      );
    end if;
  end loop;
end;
$$;

notify pgrst, 'reload schema';
