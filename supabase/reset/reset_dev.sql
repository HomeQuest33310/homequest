-- HomeQuest Dev Reset
-- Vide les données de test sans supprimer les tables, RPC ou policies.

truncate table
  chronicles,
  boss_damage_events,
  quest_assignments,
  quest_completions,
  quest_skill_rewards,
  member_skills,
  quests,
  domains,
  family_members,
  bosses,
  families,
  profiles
cascade;
