create or replace table `northstar-bq.saasbench_mini.tickets` as
with base as (
  select
    a.account_id,
    (select as value c from unnest(['billing','onboarding','bug','how_to','feature_request']) c order by rand() limit 1) as category,
    date_add(a.first_seen_date, interval cast(rand()*500 as int64) day) as opened_date
  from `northstar-bq.saasbench_mini.dim_account` a
  where rand() < 0.9
),
with_resolve as (
  select
    account_id, category, opened_date,
    case
      when rand() < 0.85 then date_add(opened_date, interval cast(1 + rand()*14 as int64) day)
      else null
    end as resolved_date
  from base
)
select
  format('T%07d', row_number() over(order by account_id, opened_date)) as ticket_id,
  account_id, category, opened_date, resolved_date,
  case when resolved_date is null then null else 1 + cast(rand()*4 as int64) end as csat_score_1_5
from with_resolve;