-- models: mart_metrics.v_nrr_monthly
create or replace view `northstar-bq.mart_metrics.v_nrr_monthly` as
with movements as (
  select
    month_end,
    account_id,
    prev_mrr,
    curr_mrr,
    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churn_mrr
  from `northstar-bq.mart_metrics.v_mrr_movements`
),
existing_base as (
  -- only accounts with revenue at the start of the month
  select * from movements where prev_mrr > 0
),
by_month as (
  select
    month_end,
    sum(prev_mrr) as starting_mrr,
    sum(expansion_mrr) as expansion_mrr,
    sum(contraction_mrr) as contraction_mrr,
    sum(churn_mrr) as churn_mrr
  from existing_base
  group by month_end
)
select
  month_end,
  starting_mrr,
  expansion_mrr,
  contraction_mrr,
  churn_mrr,
  round( (starting_mrr - contraction_mrr - churn_mrr + expansion_mrr) / nullif(starting_mrr, 0), 4) as nrr
from by_month;