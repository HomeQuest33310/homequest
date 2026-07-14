-- HomeQuest v0.8.1-alpha
-- Atomically reward every member who contributed damage to a defeated boss.

alter table public.bosses
  add column if not exists defeated_at timestamptz,
  add column if not exists rewards_distributed_at timestamptz;

create table if not exists public.boss_reward_events (
  id uuid primary key default gen_random_uuid(),
  boss_id uuid not null references public.bosses(id) on delete cascade,
  member_id uuid not null references public.family_members(id) on delete cascade,
  xp_reward integer not null check (xp_reward >= 0),
  skill_rewards jsonb not null default '[]'::jsonb
    check (jsonb_typeof(skill_rewards) = 'array'),
  awarded_at timestamptz not null default now(),
  unique (boss_id, member_id)
);

create index if not exists boss_reward_events_member_idx
on public.boss_reward_events(member_id);

alter table public.boss_reward_events enable row level security;

drop policy if exists "Members can read boss rewards"
on public.boss_reward_events;

create policy "Members can read boss rewards"
on public.boss_reward_events
for select
to authenticated
using (
  exists (
    select 1
    from public.bosses boss
    where boss.id = boss_reward_events.boss_id
      and public.is_family_member(boss.family_id)
  )
);

revoke all on table public.boss_reward_events from public, anon;
revoke insert, update, delete on table public.boss_reward_events
from authenticated;
grant select on table public.boss_reward_events to authenticated;

create or replace function public.apply_quest_completion_rewards(
  p_completion_id uuid,
  p_reviewer_member_id uuid,
  p_allow_self boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_completion public.quest_completions;
  v_quest public.quests;
  v_member public.family_members;
  v_profile public.profiles;
  v_boss public.bosses;
  v_participant record;
  v_reward_event_id uuid;
  v_new_xp integer;
  v_new_level integer;
  v_boss_defeated boolean := false;
  v_boss_reward_xp integer := 0;
  v_rewarded_participants integer := 0;
begin
  select * into v_completion
  from public.quest_completions
  where id = p_completion_id
  for update;

  if v_completion.id is null then raise exception 'Completion not found'; end if;
  if v_completion.status <> 'pending' then
    raise exception 'Completion has already been reviewed';
  end if;
  if not p_allow_self and v_completion.completed_by = p_reviewer_member_id then
    raise exception 'A guardian cannot approve their own quest';
  end if;

  select * into v_quest from public.quests where id = v_completion.quest_id;
  select * into v_member from public.family_members
  where id = v_completion.completed_by for update;
  select * into v_profile from public.profiles where id = v_member.user_id;

  v_new_xp := v_member.xp + v_quest.xp_reward;
  v_new_level := public.homequest_level_for_xp(v_new_xp);

  update public.family_members
  set xp = v_new_xp,
      gold = gold + v_quest.gold_reward,
      level = greatest(level, v_new_level)
  where id = v_member.id;

  insert into public.member_skills (member_id, skill_id, xp, level, updated_at)
  select v_member.id, reward.skill_id, reward.xp_reward,
         public.homequest_skill_level_for_xp(reward.xp_reward), now()
  from public.quest_skill_rewards reward
  where reward.quest_id = v_quest.id
  on conflict (member_id, skill_id) do update
  set xp = public.member_skills.xp + excluded.xp,
      level = public.homequest_skill_level_for_xp(
        public.member_skills.xp + excluded.xp
      ),
      updated_at = now();

  select * into v_boss
  from public.bosses
  where family_id = v_quest.family_id
    and status = 'active'
    and (ends_at is null or ends_at > now())
  order by starts_at desc
  limit 1
  for update;

  if v_boss.id is not null then
    update public.bosses
    set current_hp = greatest(0, current_hp - v_quest.boss_damage),
        status = case
          when current_hp - v_quest.boss_damage <= 0
            then 'defeated'::boss_status
          else status
        end,
        defeated_at = case
          when current_hp - v_quest.boss_damage <= 0 then now()
          else defeated_at
        end
    where id = v_boss.id;

    insert into public.boss_damage_events (boss_id, completion_id, damage)
    values (v_boss.id, v_completion.id, v_quest.boss_damage);

    v_boss_defeated := v_boss.current_hp - v_quest.boss_damage <= 0;
  end if;

  if v_boss_defeated then
    -- The row lock above guarantees that only this transaction can mark and
    -- reward the victory. The event table adds a second idempotency barrier.
    update public.bosses
    set rewards_distributed_at = now()
    where id = v_boss.id
      and rewards_distributed_at is null;

    if found then
      for v_participant in
        select distinct completion.completed_by as member_id
        from public.boss_damage_events damage
        join public.quest_completions completion
          on completion.id = damage.completion_id
        where damage.boss_id = v_boss.id
      loop
        v_reward_event_id := null;
        insert into public.boss_reward_events (
          boss_id, member_id, xp_reward, skill_rewards
        ) values (
          v_boss.id,
          v_participant.member_id,
          v_boss.xp_reward,
          v_boss.skill_rewards
        )
        on conflict (boss_id, member_id) do nothing
        returning id into v_reward_event_id;

        if v_reward_event_id is not null then
          update public.family_members
          set xp = xp + v_boss.xp_reward,
              level = greatest(
                level,
                public.homequest_level_for_xp(xp + v_boss.xp_reward)
              )
          where id = v_participant.member_id;

          insert into public.member_skills (
            member_id, skill_id, xp, level, updated_at
          )
          select
            v_participant.member_id,
            reward->>'skill_id',
            (reward->>'points')::integer,
            public.homequest_skill_level_for_xp(
              (reward->>'points')::integer
            ),
            now()
          from jsonb_array_elements(v_boss.skill_rewards) reward
          on conflict (member_id, skill_id) do update
          set xp = public.member_skills.xp + excluded.xp,
              level = public.homequest_skill_level_for_xp(
                public.member_skills.xp + excluded.xp
              ),
              updated_at = now();

          v_rewarded_participants := v_rewarded_participants + 1;
        end if;
      end loop;

      v_boss_reward_xp := v_boss.xp_reward;

      insert into public.chronicles (family_id, type, title, body)
      values (
        v_boss.family_id,
        'boss_defeated',
        v_boss.emoji || ' ' || v_boss.name || ' a été vaincu !',
        v_rewarded_participants || ' héros récompensés : +' ||
          v_boss.xp_reward || ' XP et les compétences de combat du boss.'
      );
    end if;
  end if;

  update public.quest_completions
  set status = 'approved',
      approved_by = p_reviewer_member_id,
      approved_at = now(),
      rewarded_at = now(),
      rejection_reason = null
  where id = v_completion.id;

  insert into public.chronicles (family_id, type, title, body)
  values (
    v_quest.family_id,
    'quest_completed',
    v_profile.display_name || ' a accompli « ' || v_quest.title || ' »',
    '+' || v_quest.xp_reward || ' XP, +' || v_quest.gold_reward ||
      ' or et ' || v_quest.boss_damage || ' dégâts au boss.'
  );

  -- Return the actual total progression of the member who completed the
  -- final quest, including a possible boss-victory reward.
  select xp, level into v_new_xp, v_new_level
  from public.family_members
  where id = v_member.id;

  return jsonb_build_object(
    'completion_id', v_completion.id,
    'xp_reward', v_quest.xp_reward,
    'gold_reward', v_quest.gold_reward,
    'boss_damage', case
      when v_boss.id is null then 0 else v_quest.boss_damage
    end,
    'boss_reward_xp', v_boss_reward_xp,
    'boss_rewarded_participants', v_rewarded_participants,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'boss_defeated', v_boss_defeated
  );
end;
$$;

revoke all on function public.apply_quest_completion_rewards(
  uuid, uuid, boolean
) from public, anon, authenticated;

notify pgrst, 'reload schema';
