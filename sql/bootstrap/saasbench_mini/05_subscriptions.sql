create or replace table `northstar-bq.saasbench_mini.subscriptions` as
with base as (
  select
    a.account_id,
    a.first_seen_date,
    if(rand() < 0.15, 'usage', if(rand() < 0.35, 'pro', 'team')) as plan_id
  from `northstar-bq.saasbench_mini.dim_account` a
),
prepared as (
  select
    account_id,
    plan_id,
    -- raw random start after first seen
    date_add(first_seen_date, interval cast(rand()*120 as int64) day) as start_date_raw
  from base
),
dated as (
  select
    account_id,
    plan_id,
    -- clamp start_date to today if it would be in the future
    least(start_date_raw, current_date()) as start_date
  from prepared
),
with_cancel as (
  select
    account_id,
    plan_id,
    start_date,
    -- 18% chance to cancel, but never before start, never after today
    case when rand() < 0.18 then
      least(date_add(start_date, interval cast(rand()*300 as int64) day), current_date())
    else null end as cancel_date
  from dated
)
select
  account_id,
  plan_id,
  start_date,
  cancel_date,
  case when plan_id in ('team','pro') then cast(2 + rand()*40 as int64) end as seats_committed,
  case when plan_id = 'usage' then cast(1000 + rand()*20000 as int64) end as monthly_commit_units,
  case
    when plan_id = 'team'  then (cast(2 + rand()*40 as int64)) * 20.00
    when plan_id = 'pro'   then (cast(2 + rand()*40 as int64)) * 50.00
    when plan_id = 'usage' then (cast(1000 + rand()*20000 as int64)) * 0.02
  end as estimated_monthly_mrr_usd
from with_cancel;
