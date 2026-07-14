-- Members may edit the shared list but cannot move an item to another
-- kingdom or impersonate its original author.

revoke update on public.shopping_items from authenticated;
grant update (
  name,
  quantity,
  category,
  note,
  status,
  claimed_by,
  purchased_by,
  purchased_at,
  archived_at,
  updated_at
) on public.shopping_items to authenticated;

notify pgrst, 'reload schema';
