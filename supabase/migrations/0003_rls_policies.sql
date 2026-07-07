-- HomeQuest MVP Row Level Security policies.
-- These policies are intentionally conservative and will evolve as features are added.

alter table profiles enable row level security;
alter table families enable row level security;
alter table family_members enable row level security;
alter table quests enable row level security;
alter table quest_assignments enable row level security;
alter table quest_completions enable row level security;
alter table bosses enable row level security;
alter table skills enable row level security;
alter table member_skills enable row level security;
alter table quest_skill_rewards enable row level security;

create or replace function is_family_member(target_family_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = auth.uid()
      and (fm.expires_at is null or fm.expires_at > now())
  );
$$;

create or replace function is_family_guardian(target_family_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = auth.uid()
      and fm.role = 'guardian'
      and (fm.expires_at is null or fm.expires_at > now())
  );
$$;

create policy "Profiles are readable by authenticated users"
on profiles for select
to authenticated
using (true);

create policy "Users can insert their own profile"
on profiles for insert
to authenticated
with check (id = auth.uid());

create policy "Users can update their own profile"
on profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "Members can read their families"
on families for select
to authenticated
using (is_family_member(id));

create policy "Authenticated users can create families"
on families for insert
to authenticated
with check (owner_id = auth.uid());

create policy "Guardians can update families"
on families for update
to authenticated
using (is_family_guardian(id))
with check (is_family_guardian(id));

create policy "Members can read family memberships"
on family_members for select
to authenticated
using (is_family_member(family_id));

create policy "Family owners can create first guardian membership"
on family_members for insert
to authenticated
with check (
  user_id = auth.uid()
  or is_family_guardian(family_id)
);

create policy "Members can read quests"
on quests for select
to authenticated
using (is_family_member(family_id));

create policy "Guardians can manage quests"
on quests for all
to authenticated
using (is_family_guardian(family_id))
with check (is_family_guardian(family_id));

create policy "Members can read bosses"
on bosses for select
to authenticated
using (is_family_member(family_id));

create policy "Guardians can manage bosses"
on bosses for all
to authenticated
using (is_family_guardian(family_id))
with check (is_family_guardian(family_id));

create policy "Skills are readable by authenticated users"
on skills for select
to authenticated
using (true);

create policy "Members can read member skills"
on member_skills for select
to authenticated
using (
  exists (
    select 1
    from family_members fm
    where fm.id = member_skills.member_id
      and is_family_member(fm.family_id)
  )
);

create policy "Members can read quest skill rewards"
on quest_skill_rewards for select
to authenticated
using (
  exists (
    select 1
    from quests q
    where q.id = quest_skill_rewards.quest_id
      and is_family_member(q.family_id)
  )
);
