-- models: mart_metrics.v_mrr_month_end
create or replace view `northstar-bq.mart_metrics.v_mrr_month_end` as
with months as (
  select distinct
    date_trunc(day, month) as month_start_date,
    date_sub(date_add(date_trunc(day, month), interval 1 month), interval 1 day) as month_end_date
  from `northstar-bq.saasbench_mini.calendar_day`
  where day <= current_date()
),
active_subscriptions as (
  select
    months.month_start_date,
    months.month_end_date,
    subscriptions.account_id,
    subscriptions.plan_id,
    subscriptions.estimated_monthly_mrr_usd as monthly_recurring_revenue
  from months
  join `northstar-bq.saasbench_mini.subscriptions` subscriptions
    on months.month_end_date between subscriptions.start_date
                                 and coalesce(subscriptions.cancel_date, months.month_end_date)
)
select
  month_start_date,
  month_end_date,
  account_id,
  plan_id,
  monthly_recurring_revenue
from active_subscriptions;
