create or replace table `northstar-bq.saasbench_mini.usage_daily` as
with days as (
  select s.account_id, s.plan_id, d.day as usage_date, s.cancel_date
  from `northstar-bq.saasbench_mini.subscriptions` s
  join `northstar-bq.saasbench_mini.calendar_day` d
    on d.day between s.start_date and coalesce(s.cancel_date, current_date())
)
select
  account_id,
  plan_id,
  usage_date,
  case when plan_id = 'usage' then cast(20 + rand()*200 as int64)
       when plan_id = 'pro'   then cast(10 + rand()*100 as int64)
       else cast(5 + rand()*60 as int64) end as billable_units,
  cast(50 + rand()*500 as int64) as feature_events,
  if(rand() < 0.07, true, false) as api_error_flag
from days
where rand() < 0.55;
