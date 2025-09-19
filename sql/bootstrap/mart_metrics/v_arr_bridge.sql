-- models: mart_metrics.v_arr_bridge
create or replace view `northstar-bq.mart_metrics.v_arr_bridge` as
with revenue_by_month as (
  select
    month_start_date,
    sum(new_revenue) as new_revenue,
    sum(expansion_revenue) as expansion_revenue,
    sum(contraction_revenue) as contraction_revenue,
    sum(churned_revenue) as churned_revenue,
    sum(current_monthly_revenue) as ending_mrr
  from `northstar-bq.mart_metrics.v_mrr_movements`
  group by month_start_date
)
select
  month_start_date,
  12 * new_revenue as new_arr,
  12 * expansion_revenue as expansion_arr,
  12 * contraction_revenue as contraction_arr,
  12 * churned_revenue as churned_arr,
  12 * ending_mrr as ending_arr
from revenue_by_month;
