-- HomeQuest - Les initiatives volontaires se debloquent au niveau 10.

create or replace function public.enforce_voluntary_quest_minimum_level()
returns trigger
language plpgsql
security invoker
set search_path = public, auth
as $$
declare
  v_level integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select fm.level
  into v_level
  from public.family_members fm
  where fm.id = new.requested_by
    and fm.user_id = auth.uid()
    and fm.is_active
    and (fm.expires_at is null or fm.expires_at > now());

  if coalesce(v_level, 0) < 10 then
    raise exception 'Aventurier niveau 10 requis';
  end if;

  return new;
end;
$$;

drop trigger if exists voluntary_quest_minimum_level
on public.voluntary_quest_requests;

create trigger voluntary_quest_minimum_level
before insert on public.voluntary_quest_requests
for each row
execute function public.enforce_voluntary_quest_minimum_level();

revoke all on function public.enforce_voluntary_quest_minimum_level()
from public, anon, authenticated;

notify pgrst, 'reload schema';
