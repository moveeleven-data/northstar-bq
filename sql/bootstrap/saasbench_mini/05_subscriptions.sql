create or replace table `northstar-bq.northstar_app.subscriptions` as
with base as (
  select
    a.account_id,
    a.first_seen_date,
    -- deterministic plan pick: ~15% usage, next ~20% pro, else team
    case
      when mod(abs(farm_fingerprint(concat(a.account_id, ':plan'))), 100) < 15 then 'usage'
      when mod(abs(farm_fingerprint(concat(a.account_id, ':plan'))), 100) < 35 then 'pro'
      else 'team'
    end as plan_id
  from `northstar-bq.northstar_app.dim_account` a
),
seeded as (
  select
    account_id,
    plan_id,
    first_seen_date,
    -- deterministic offsets
    mod(abs(farm_fingerprint(concat(account_id, ':start'))), 121) as start_offset_days,      -- 0..120
    mod(abs(farm_fingerprint(concat(account_id, ':cancel_offset'))), 301) as cancel_offset_days, -- 0..300
    -- deterministic commitments
    mod(abs(farm_fingerprint(concat(account_id, ':seats'))), 39) + 2   as seats_calc,  -- 2..40
    mod(abs(farm_fingerprint(concat(account_id, ':units'))), 20001) + 1000 as units_calc -- 1000..21000
  from base
),
dated as (
  select
    account_id,
    plan_id,
    least(date_add(first_seen_date, interval start_offset_days day), current_date()) as start_date,
    case
      -- ~18% chance to cancel, never before start, never after today
      when mod(abs(farm_fingerprint(concat(account_id, ':cancel_flag'))), 100) < 18 then
        least(
          date_add(least(date_add(first_seen_date, interval start_offset_days day), current_date()),
                   interval cancel_offset_days day),
          current_date()
        )
      else null
    end as cancel_date,
    case when plan_id in ('team','pro') then cast(seats_calc as int64) end as seats_committed,
    case when plan_id = 'usage' then cast(units_calc as int64) end as monthly_commit_units
  from seeded
),
with_prices as (
  select
    d.*,
    p.list_price_month,
    p.unit_rate_usd,
    p.pricing_model
  from dated d
  join `northstar-bq.northstar_app.dim_plan` p using (plan_id)
)
select
  account_id,
  plan_id,
  start_date,
  cancel_date,
  seats_committed,
  monthly_commit_units,
  case
    when plan_id in ('team','pro') then cast(seats_committed as float64) * list_price_month
    when plan_id = 'usage' then cast(monthly_commit_units as float64) * unit_rate_usd
  end as estimated_monthly_mrr_usd
from with_prices;
