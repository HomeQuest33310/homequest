-- HomeQuest v0.5.3-alpha
-- Supabase may grant EXECUTE on new functions directly to anon through its
-- default privileges. Privileged HomeQuest RPCs must require authentication.

do $$
declare
  v_function record;
begin
  for v_function in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  loop
    execute format(
      'revoke execute on function %s from public, anon',
      v_function.signature
    );
  end loop;
end;
$$;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

notify pgrst, 'reload schema';
