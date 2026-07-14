-- Guardian reward management and the full Kingdom legend journal.

alter table public.reward_suggestions
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid
    references public.family_members(id) on delete set null;

create index if not exists reward_suggestions_archived_by_idx
  on public.reward_suggestions(archived_by)
  where archived_by is not null;

create or replace function public.update_collective_reward(
  p_suggestion_id uuid,
  p_title text,
  p_description text,
  p_quest_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  suggestion public.reward_suggestions%rowtype;
  result jsonb;
  boss_defeated boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into suggestion
  from public.reward_suggestions
  where id = p_suggestion_id
  for update;

  if suggestion.id is null then
    raise exception 'Collective reward not found';
  end if;
  if not public.is_family_guardian(suggestion.family_id) then
    raise exception 'Only guardians can update collective rewards';
  end if;
  if suggestion.status <> 'approved' then
    raise exception 'Only approved collective rewards can be updated';
  end if;
  if suggestion.archived_at is not null then
    raise exception 'An archived reward cannot be updated';
  end if;
  if suggestion.delivered_at is not null then
    raise exception 'A delivered reward cannot be updated';
  end if;
  if nullif(trim(p_title), '') is null then
    raise exception 'A reward title is required';
  end if;
  if p_quest_count is not null and p_quest_count not between 1 and 100 then
    raise exception 'Quest goal must be between 1 and 100';
  end if;
  if p_quest_count is not null
     and p_quest_count < suggestion.completed_quest_count then
    raise exception 'Quest goal cannot be lower than current progress';
  end if;
  if p_quest_count is null and suggestion.boss_id is null then
    raise exception 'Keep a quest goal because no boss is linked';
  end if;

  select coalesce(boss.status = 'defeated', false)
  into boss_defeated
  from public.bosses boss
  where boss.id = suggestion.boss_id;

  update public.reward_suggestions reward
  set guardian_title = trim(p_title),
      guardian_description = trim(coalesce(p_description, '')),
      guardian_quest_count = p_quest_count,
      fulfilled_at = case
        when (p_quest_count is null
              or reward.completed_quest_count >= p_quest_count)
         and (reward.boss_id is null or coalesce(boss_defeated, false))
          then coalesce(reward.fulfilled_at, now())
        else null
      end,
      updated_at = now()
  where reward.id = suggestion.id
  returning to_jsonb(reward.*) into result;

  return result;
end;
$$;

create or replace function public.archive_collective_reward(
  p_suggestion_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  suggestion public.reward_suggestions%rowtype;
  guardian_member_id uuid;
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into suggestion
  from public.reward_suggestions
  where id = p_suggestion_id
  for update;

  if suggestion.id is null then
    raise exception 'Collective reward not found';
  end if;
  if not public.is_family_guardian(suggestion.family_id) then
    raise exception 'Only guardians can archive collective rewards';
  end if;
  if suggestion.archived_at is not null then
    raise exception 'The collective reward is already archived';
  end if;

  select member.id into guardian_member_id
  from public.family_members member
  where member.family_id = suggestion.family_id
    and member.user_id = auth.uid()
    and member.role = 'guardian'
    and member.is_active
    and (member.expires_at is null or member.expires_at > now())
  limit 1;

  if guardian_member_id is null then
    raise exception 'Active guardian membership required';
  end if;

  update public.reward_suggestions
  set archived_at = now(),
      archived_by = guardian_member_id,
      updated_at = now()
  where id = suggestion.id
  returning to_jsonb(reward_suggestions.*) into result;

  return result;
end;
$$;

create or replace function public.list_kingdom_legend(
  p_family_id uuid,
  p_limit integer default 500
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_family_member(p_family_id) then
    raise exception 'Kingdom membership required';
  end if;
  if p_limit not between 1 and 1000 then
    raise exception 'Journal limit must be between 1 and 1000';
  end if;

  select coalesce(jsonb_agg(to_jsonb(event) order by event.occurred_at desc), '[]'::jsonb)
  into result
  from (
    select *
    from (
      select
        'chronicle:' || chronicle.id::text as id,
        'chronicle'::text as category,
        chronicle.type::text as event_type,
        chronicle.title,
        coalesce(chronicle.body, '') as body,
        'recorded'::text as status,
        chronicle.created_at as occurred_at,
        '{}'::jsonb as metadata
      from public.chronicles chronicle
      where chronicle.family_id = p_family_id
        and chronicle.type::text not in (
          'quest_completed', 'boss_defeated', 'reward_claimed',
          'mercenary_joined'
        )

      union all

      select
        'member:' || member.id::text,
        'member',
        member.role::text || '_joined',
        case member.role
          when 'mercenary' then 'Un Mercenaire rejoint le Royaume'
          when 'guardian' then 'Un Gardien rejoint le Conseil'
          else 'Un Aventurier rejoint la Guilde'
        end,
        profile.display_name || ' entre dans la légende du Royaume.',
        case when member.is_active then 'active' else 'inactive' end,
        coalesce(member.accepted_at, member.joined_at, now()),
        jsonb_build_object(
          'member_name', profile.display_name,
          'role', member.role::text,
          'level', member.level,
          'xp', member.xp,
          'gold', member.gold
        )
      from public.family_members member
      join public.profiles profile on profile.id = member.user_id
      where member.family_id = p_family_id

      union all

      select
        'invitation:' || invitation.id::text,
        'invitation',
        invitation.role::text || '_invited',
        case invitation.role
          when 'mercenary' then 'Invitation d’un Mercenaire'
          when 'guardian' then 'Invitation au Conseil des Gardiens'
          else 'Invitation d’un Aventurier'
        end,
        'Portée : ' ||
          case invitation.membership_scope
            when 'domain' then coalesce(domain.name, 'Domaine')
            else 'Royaume entier'
          end || ' · Statut : ' || invitation.status::text,
        invitation.status::text,
        invitation.created_at,
        jsonb_build_object(
          'role', invitation.role::text,
          'scope', invitation.membership_scope::text,
          'domain_name', domain.name,
          'expires_at', invitation.expires_at
        )
      from public.family_invitations invitation
      left join public.domains domain on domain.id = invitation.domain_id
      where invitation.family_id = p_family_id

      union all

      select
        'quest:' || quest.id::text,
        'quest',
        'quest_registered',
        quest.emoji || ' ' || quest.title,
        'Tâche réelle : ' || quest.real_task ||
          ' · XP : ' || quest.xp_reward ||
          ' · Or : ' || quest.gold_reward,
        quest.status::text,
        quest.created_at,
        jsonb_build_object(
          'quest_id', quest.id,
          'real_task', quest.real_task,
          'xp_reward', quest.xp_reward,
          'gold_reward', quest.gold_reward,
          'boss_damage', quest.boss_damage,
          'element', quest.element
        )
      from public.quests quest
      where quest.family_id = p_family_id

      union all

      select
        'completion:' || completion.id::text,
        'quest',
        'quest_completed',
        profile.display_name || ' accomplit « ' || quest.title || ' »',
        '+' || quest.xp_reward || ' XP · +' || quest.gold_reward ||
          ' Or · ' || quest.boss_damage || ' dégâts au boss',
        completion.status::text,
        coalesce(completion.approved_at, completion.completed_at),
        jsonb_build_object(
          'quest_id', quest.id,
          'quest_title', quest.title,
          'member_name', profile.display_name,
          'xp_reward', quest.xp_reward,
          'gold_reward', quest.gold_reward,
          'boss_damage', quest.boss_damage
        )
      from public.quest_completions completion
      join public.quests quest on quest.id = completion.quest_id
      join public.family_members member on member.id = completion.completed_by
      join public.profiles profile on profile.id = member.user_id
      where quest.family_id = p_family_id

      union all

      select
        'boss:' || boss.id::text,
        'boss',
        'boss_' || boss.status::text,
        boss.emoji || ' ' || boss.name,
        'Statut : ' || boss.status::text || ' · ' ||
          boss.current_hp || '/' || boss.max_hp || ' PV · Participants : ' ||
          coalesce((
            select string_agg(distinct profile.display_name, ', ')
            from public.boss_reward_events reward_event
            join public.family_members participant
              on participant.id = reward_event.member_id
            join public.profiles profile on profile.id = participant.user_id
            where reward_event.boss_id = boss.id
          ), 'Aucun'),
        boss.status::text,
        coalesce(boss.ends_at, boss.starts_at, boss.created_at),
        jsonb_build_object(
          'boss_id', boss.id,
          'element', boss.element,
          'current_hp', boss.current_hp,
          'max_hp', boss.max_hp,
          'special_item', boss.special_item
        )
      from public.bosses boss
      where boss.family_id = p_family_id

      union all

      select
        'reward:' || reward.id::text,
        'reward',
        case
          when reward.archived_at is not null then 'reward_archived'
          when reward.delivered_at is not null then 'reward_delivered'
          when reward.fulfilled_at is not null then 'reward_unlocked'
          else 'reward_' || reward.status::text
        end,
        coalesce(nullif(trim(reward.guardian_title), ''), reward.title),
        case
          when reward.archived_at is not null then 'Récompense archivée'
          when reward.delivered_at is not null then 'Récompense remise au Royaume'
          when reward.fulfilled_at is not null then 'Récompense débloquée, remise en attente'
          when reward.status = 'approved' then
            'Progression : ' || reward.completed_quest_count || '/' ||
              coalesce(reward.guardian_quest_count::text, '—') || ' quêtes'
          when reward.status = 'rejected' then 'Souhait refusé par le Conseil'
          else 'Souhait en attente du Conseil'
        end,
        case
          when reward.archived_at is not null then 'archived'
          when reward.delivered_at is not null then 'delivered'
          when reward.fulfilled_at is not null then 'unlocked'
          else reward.status::text
        end,
        coalesce(
          reward.archived_at, reward.delivered_at, reward.fulfilled_at,
          reward.reviewed_at, reward.created_at
        ),
        jsonb_build_object(
          'reward_id', reward.id,
          'completed_quest_count', reward.completed_quest_count,
          'guardian_quest_count', reward.guardian_quest_count,
          'boss_theme', reward.guardian_boss_theme,
          'created_by_guardian', reward.created_by_guardian
        )
      from public.reward_suggestions reward
      where reward.family_id = p_family_id
    ) all_events
    order by occurred_at desc
    limit p_limit
  ) event;

  return result;
end;
$$;

revoke all on function public.update_collective_reward(uuid, text, text, integer)
  from public, anon;
grant execute on function public.update_collective_reward(uuid, text, text, integer)
  to authenticated;

revoke all on function public.archive_collective_reward(uuid)
  from public, anon;
grant execute on function public.archive_collective_reward(uuid)
  to authenticated;

revoke all on function public.list_kingdom_legend(uuid, integer)
  from public, anon;
grant execute on function public.list_kingdom_legend(uuid, integer)
  to authenticated;

notify pgrst, 'reload schema';
