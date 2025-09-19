-- models: mart_metrics.v_activation_7d
create or replace view `northstar-bq.mart_metrics.v_activation_7d` as
with signups as (
  select
    user_id,
    min(event_timestamp) as first_signup_ts
  from `northstar-bq.saasbench_mini.product_events`
  where lower(event_name) = 'signup'
  group by user_id
),
activation as (
  select
    s.user_id,
    min(e.event_timestamp) as first_activation_ts
  from signups s
  join `northstar-bq.saasbench_mini.product_events` e
    on e.user_id = s.user_id
   and lower(e.event_name) in ('project_create','file_upload','job_run')
   and e.event_timestamp between s.first_signup_ts and timestamp_add(s.first_signup_ts, interval 7 day)
  group by s.user_id
),
labeled as (
  select
    s.user_id,
    timestamp_trunc(s.first_signup_ts, month) as signup_month,
    case when a.first_activation_ts is not null then 1 else 0 end as activated_7d
  from signups s
  left join activation a using (user_id)
)
select
  signup_month,
  count(*) as signups,
  sum(activated_7d) as activated_7d,
  round(safe_divide(sum(activated_7d), count(*)), 4) as activation_rate_7d
from labeled
group by signup_month
order by signup_month;