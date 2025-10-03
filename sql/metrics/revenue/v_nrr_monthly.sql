/*
   v_nrr_monthly.sql
   Purpose: Calculate Net Revenue Retention (NRR) at the company level by month.
            Excludes new revenue and measures retention based on accounts with starting MRR > 0.
*/

with

nrr_calc as (
    select
        month_end_date
      , round(
            (sum(current_month_mrr) - sum(new_mrr))
            / nullif(sum(previous_month_mrr), 0)
            * 100
          , 2
        ) as current_month_nrr
    from `northstar-bq.northstar_metrics.v_mrr_movements`
    group by
        month_end_date
)

select
    month_end_date
  , current_month_nrr
from nrr_calc;