create or replace table `northstar-bq.saasbench_mini.opportunities` as
with base as (
  select
    a.account_id,
    -- stable randoms per account to choose source and stage
    mod(abs(farm_fingerprint(a.account_id)), 10000) / 10000.0 as r_source,
    mod(abs(farm_fingerprint(concat(a.account_id, ':stage'))), 10000) / 10000.0 as r_stage,
    round(1000 + rand()*90000, 2) as amount_usd,
    date_add(a.first_seen_date, interval cast(rand()*400 as int64) day) as created_date
  from `northstar-bq.saasbench_mini.dim_account` a
  where rand() < 0.6
),
labeled as (
  select
    account_id,
    case
      when r_source < 0.33 then 'inbound'
      when r_source < 0.66 then 'outbound'
      else 'partner'
    end as source,
    case
      when r_stage < 0.40 then 'discovery'
      when r_stage < 0.75 then 'evaluation'
      when r_stage < 0.90 then 'procurement'
      when r_stage < 0.96 then 'won'
      else 'lost'
    end as stage,
    amount_usd,
    created_date
  from base
)
select
  format('O%06d', row_number() over(order by account_id, created_date)) as opportunity_id,
  account_id,
  source,
  stage,
  amount_usd,
  created_date,
  case
    when stage in ('won','lost') then date_add(created_date, interval cast(1 + rand()*120 as int64) day)
    else null
  end as closed_date
from labeled;
