-- Premium profile avatars bought with the member's personal gold balance.
create table if not exists public.profile_avatar_unlocks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  avatar_key text not null check (
    avatar_key in (
      'akatsuki_ninja',
      'warrior_queen',
      'totoro',
      'meerkat'
    )
  ),
  gold_spent integer not null check (gold_spent > 0),
  purchased_at timestamptz not null default now(),
  primary key (user_id, avatar_key)
);

alter table public.profile_avatar_unlocks enable row level security;

revoke all on table public.profile_avatar_unlocks from anon;
revoke all on table public.profile_avatar_unlocks from authenticated;
grant select on table public.profile_avatar_unlocks to authenticated;

drop policy if exists "Users can view their unlocked avatars"
  on public.profile_avatar_unlocks;
create policy "Users can view their unlocked avatars"
  on public.profile_avatar_unlocks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.purchase_profile_avatar(
  p_family_id uuid,
  p_avatar_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_member_id uuid;
  v_gold integer;
  v_price constant integer := 100;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_avatar_key not in (
    'akatsuki_ninja',
    'warrior_queen',
    'totoro',
    'meerkat'
  ) then
    raise exception 'This avatar is not available for purchase';
  end if;

  -- Serialize purchases for this profile so concurrent requests cannot charge
  -- the same avatar twice from different family memberships.
  perform 1
  from public.profiles
  where id = v_user_id
  for update;

  select id, gold
  into v_member_id, v_gold
  from public.family_members
  where family_id = p_family_id
    and user_id = v_user_id
    and is_active = true
  for update;

  if v_member_id is null then
    raise exception 'Active family membership required';
  end if;

  if exists (
    select 1
    from public.profile_avatar_unlocks
    where user_id = v_user_id
      and avatar_key = p_avatar_key
  ) then
    return jsonb_build_object(
      'avatar_key', p_avatar_key,
      'price', 0,
      'remaining_gold', v_gold,
      'already_unlocked', true
    );
  end if;

  if v_gold < v_price then
    raise exception 'Not enough gold';
  end if;

  update public.family_members
  set gold = gold - v_price
  where id = v_member_id
  returning gold into v_gold;

  insert into public.profile_avatar_unlocks (
    user_id,
    avatar_key,
    gold_spent
  )
  values (
    v_user_id,
    p_avatar_key,
    v_price
  );

  return jsonb_build_object(
    'avatar_key', p_avatar_key,
    'price', v_price,
    'remaining_gold', v_gold,
    'already_unlocked', false
  );
end;
$$;

revoke execute on function public.purchase_profile_avatar(uuid, text)
  from public;
revoke execute on function public.purchase_profile_avatar(uuid, text)
  from anon;
grant execute on function public.purchase_profile_avatar(uuid, text)
  to authenticated;

create or replace function public.update_my_profile(
  p_display_name text,
  p_avatar_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_display_name text := trim(p_display_name);
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if char_length(v_display_name) not between 2 and 32 then
    raise exception 'Display name must contain between 2 and 32 characters';
  end if;

  if p_avatar_key not in (
    'guardian',
    'knight',
    'mage',
    'ranger',
    'healer',
    'scholar',
    'explorer',
    'druid',
    'cook',
    'builder',
    'star',
    'dragon',
    'akatsuki_ninja',
    'warrior_queen',
    'totoro',
    'meerkat'
  ) then
    raise exception 'This avatar is not available';
  end if;

  update public.profiles
  set display_name = v_display_name,
      avatar_key = p_avatar_key
  where id = v_user_id;

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

revoke execute on function public.update_my_profile(text, text)
  from public;
revoke execute on function public.update_my_profile(text, text)
  from anon;
grant execute on function public.update_my_profile(text, text)
  to authenticated;

create or replace function public.enforce_premium_profile_avatar_unlock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.avatar_key in (
    'akatsuki_ninja',
    'warrior_queen',
    'totoro',
    'meerkat'
  ) and not exists (
    select 1
    from public.profile_avatar_unlocks
    where user_id = new.id
      and avatar_key = new.avatar_key
  ) then
    raise exception 'This premium avatar has not been unlocked';
  end if;

  return new;
end;
$$;

revoke execute on function public.enforce_premium_profile_avatar_unlock()
  from public;
revoke execute on function public.enforce_premium_profile_avatar_unlock()
  from anon;
revoke execute on function public.enforce_premium_profile_avatar_unlock()
  from authenticated;

drop trigger if exists enforce_premium_profile_avatar_unlock
  on public.profiles;
create trigger enforce_premium_profile_avatar_unlock
before insert or update of avatar_key on public.profiles
for each row
execute function public.enforce_premium_profile_avatar_unlock();

notify pgrst, 'reload schema';
