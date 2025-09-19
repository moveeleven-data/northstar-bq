-- models: mart_metrics.v_pql_accounts
create or replace view `northstar-bq.mart_metrics.v_pql_accounts` as
with first_signup as (
  select
    account_id,
    min(event_timestamp) as first_signup_ts
  from `northstar-bq.saasbench_mini.product_events`
  where lower(event_name) = 'signup'
  group by account_id
),
windowed as (
  select
    fs.account_id,
    fs.first_signup_ts,
    timestamp_add(fs.first_signup_ts, interval 28 day) as window_end_ts
  from first_signup fs
),
events_in_window as (
  select
    w.account_id,
    e.event_name,
    count(*) as event_count
  from windowed w
  join `northstar-bq.saasbench_mini.product_events` e
    on e.account_id = w.account_id
   and e.event_timestamp between w.first_signup_ts and w.window_end_ts
  group by w.account_id, e.event_name
),
pql_flags as (
  select
    account_id,
    max(case when lower(event_name) = 'subscribe_click' then 1 else 0 end) as has_subscribe_click,
    max(case when lower(event_name) in ('job_run','api_call') and event_count >= 3 then 1 else 0 end) as has_usage_signal
  from events_in_window
  group by account_id
),
pql as (
  select
    account_id,
    1 as is_pql
  from pql_flags
  where has_subscribe_click = 1 or has_usage_signal = 1
)
select
  p.account_id,
  date_trunc(timestamp(w.first_signup_ts), month) as pql_month
from pql p
join windowed w using (account_id);