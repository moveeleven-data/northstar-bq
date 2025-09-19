create or replace table `northstar-bq.saasbench_mini.product_events` as
with users as (
  select user_id, account_id, created_date
  from `northstar-bq.saasbench_mini.dim_user`
),
days as (
  select day as event_date
  from `northstar-bq.saasbench_mini.calendar_day`
  where day >= date_sub(current_date(), interval 365 day)
),
base as (
  -- one row per user per day after user creation, then thin to ~10%
  select
    u.account_id,
    u.user_id,
    d.event_date
  from users u
  join days d
    on d.event_date between u.created_date and current_date()
  where rand() < 0.10
),
scored as (
  -- deterministic 0..1 score per row
  select
    account_id,
    user_id,
    event_date,
    mod(abs(farm_fingerprint(concat(user_id, ':', cast(event_date as string)))), 10000) / 10000.0 as r
  from base
)
select
  timestamp_add(timestamp(event_date), interval cast(r * 86400 as int64) second) as event_timestamp,
  account_id,
  user_id,
  case
    when r < 0.12 then 'signup'
    when r < 0.30 then 'project_create'
    when r < 0.45 then 'invite_sent'
    when r < 0.65 then 'file_upload'
    when r < 0.80 then 'job_run'
    when r < 0.92 then 'api_call'
    when r < 0.97 then 'paywall_view'
    else 'subscribe_click'
  end as event_name
from scored;
