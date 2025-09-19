-- models: mart_metrics.v_mrr_movements (filtered to real current months)
create or replace view `northstar-bq.mart_metrics.v_mrr_movements` as
with monthly_snapshots as (
  select
    month_start_date,
    account_id,
    sum(monthly_recurring_revenue) as monthly_recurring_revenue
  from `northstar-bq.mart_metrics.v_mrr_month_end`
  group by month_start_date, account_id
),
current_month as (
  select * from monthly_snapshots
),
previous_month as (
  select
    date_add(month_start_date, interval 1 month) as month_start_date,
    account_id,
    monthly_recurring_revenue as previous_monthly_revenue
  from monthly_snapshots
),
joined as (
  select
    coalesce(current_month.month_start_date, previous_month.month_start_date) as month_start_date,
    coalesce(current_month.account_id, previous_month.account_id) as account_id,
    coalesce(current_month.monthly_recurring_revenue, 0) as current_monthly_revenue,
    coalesce(previous_month.previous_monthly_revenue, 0) as previous_monthly_revenue
  from current_month
  full join previous_month
    on current_month.month_start_date = previous_month.month_start_date
   and current_month.account_id      = previous_month.account_id
)
select
  month_start_date,
  account_id,
  previous_monthly_revenue,
  current_monthly_revenue,
  case when previous_monthly_revenue = 0 and current_monthly_revenue > 0
       then current_monthly_revenue else 0 end as new_revenue,
  case when previous_monthly_revenue > 0 and current_monthly_revenue > previous_monthly_revenue
       then current_monthly_revenue - previous_monthly_revenue else 0 end as expansion_revenue,
  case when previous_monthly_revenue > 0 and current_monthly_revenue < previous_monthly_revenue and current_monthly_revenue > 0
       then previous_monthly_revenue - current_monthly_revenue else 0 end as contraction_revenue,
  case when previous_monthly_revenue > 0 and current_monthly_revenue = 0
       then previous_monthly_revenue else 0 end as churned_revenue
from joined
where month_start_date in (select distinct month_start_date from current_month);
