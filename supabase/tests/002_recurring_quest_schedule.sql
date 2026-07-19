begin;

create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(3);

select is(
  public.homequest_next_daily_occurrence(
    '2026-07-19 06:30:00+00'::timestamptz,
    '2026-07-19 07:00:00+00'::timestamptz
  ),
  '2026-07-20 06:30:00+00'::timestamptz,
  'a daily quest returns the next day at the configured Paris hour'
);

select is(
  public.homequest_next_daily_occurrence(
    '2026-07-19 06:30:00+00'::timestamptz,
    '2026-07-22 05:00:00+00'::timestamptz
  ),
  '2026-07-22 06:30:00+00'::timestamptz,
  'a missed daily quest remains aligned with its configured hour'
);

select is(
  public.homequest_next_daily_occurrence(
    '2026-07-19 06:30:00+00'::timestamptz,
    '2026-10-24 07:00:00+00'::timestamptz
  ),
  '2026-10-25 07:30:00+00'::timestamptz,
  'the configured local hour is preserved across daylight saving time'
);

select * from finish();
rollback;
