create index if not exists reward_suggestions_reviewed_by_idx
  on public.reward_suggestions(reviewed_by)
  where reviewed_by is not null;
