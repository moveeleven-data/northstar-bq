create or replace table `northstar-bq.saasbench_mini.invoices` as
with months as (
  select date as m
  from unnest(generate_date_array(date_sub(current_date(), interval 18 month), current_date(), interval 1 month)) as date
),
active as (
  select account_id, plan_id, start_date, cancel_date, estimated_monthly_mrr_usd
  from `northstar-bq.saasbench_mini.subscriptions`
)
select
  date_trunc(m, month) as invoice_month,
  a.account_id,
  a.plan_id,
  case
    when a.plan_id = 'usage' then round(a.estimated_monthly_mrr_usd * (0.7 + rand()*0.8), 2)
    else round(a.estimated_monthly_mrr_usd * (0.95 + rand()*0.2), 2)
  end as invoice_amount_usd,
  if(rand() < 0.03, round((rand()*0.3) * a.estimated_monthly_mrr_usd, 2), 0.00) as credit_amount_usd
from months, unnest([m]) as month
join active a
  on month between date_trunc(a.start_date, month) and date_trunc(coalesce(a.cancel_date, current_date()), month);