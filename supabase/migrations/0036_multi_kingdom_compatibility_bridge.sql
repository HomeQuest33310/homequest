-- Keep legacy creation RPCs operational while the application migrates
-- feature by feature to explicit kingdom selection.

alter table public.domains alter column kingdom_id drop not null;
alter table public.quests alter column kingdom_id drop not null;
alter table public.bosses alter column kingdom_id drop not null;

comment on column public.domains.kingdom_id is
  'Temporary nullable bridge; new domain management will always set a kingdom.';
comment on column public.quests.kingdom_id is
  'Temporary nullable bridge; inferred from the selected domain during migration.';
comment on column public.bosses.kingdom_id is
  'Temporary nullable bridge; future boss creation will use the selected kingdom.';

notify pgrst, 'reload schema';
