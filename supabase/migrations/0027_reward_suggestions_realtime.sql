-- HomeQuest v0.4.x
-- Diffuse les décisions des Gardiens aux auteurs des souhaits en temps réel.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reward_suggestions'
  ) then
    alter publication supabase_realtime
      add table public.reward_suggestions;
  end if;
end;
$$;

-- L'ancien statut doit être présent dans les événements UPDATE afin de
-- distinguer une décision d'un simple changement de progression.
alter table public.reward_suggestions replica identity full;
