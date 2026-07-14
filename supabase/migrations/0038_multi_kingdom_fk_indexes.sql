-- Cover the remaining foreign keys reported by the database advisor.

create index if not exists kingdoms_created_by_idx
  on public.kingdoms(created_by);

create index if not exists kingdom_members_assigned_by_idx
  on public.kingdom_members(assigned_by)
  where assigned_by is not null;
