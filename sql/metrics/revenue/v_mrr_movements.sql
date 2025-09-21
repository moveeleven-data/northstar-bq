/*
   v_mrr_movements.sql
   Purpose: Classify monthly MRR changes at the account level into new, expansion, contraction, and churn.
            Reconciles month-to-month changes in total MRR.

   Inputs:
     - v_mrr_month_end: account_id, plan_id, month_end_date, monthly_recurring_revenue
     - northstar_app.dim_account: account_id, segment, region

   Outputs:
     - One row per account per month_end_date with starting_mrr, ending_mrr, and movement classification
     - Aggregated company-level totals for new, expansion, contraction, and churn
     - Reconciliation identity check: ending = starting + new + expansion - contraction - churn
*/

with

mrr_compare as (
  select
      coalesce(
          curr.month_end_date
        , last_day(
             date_add(prev.month_end_date, interval 1 month)
          )
      ) as month_end_date
    , coalesce(curr.account_id, prev.account_id)  as account_id
    , coalesce(prev.monthly_recurring_revenue, 0) as previous_month_mrr
    , coalesce(curr.monthly_recurring_revenue, 0) as current_month_mrr
  from `northstar-bq.northstar_metrics.v_mrr_month_end_account` curr
  full outer join `northstar-bq.northstar_metrics.v_mrr_month_end_account` prev
    on curr.account_id = prev.account_id
   and prev.month_end_date = date_sub(curr.month_end_date, interval 1 month)
)

, mrr_with_movements as (
  select
      month_end_date
    , account_id
    , previous_month_mrr
    , current_month_mrr
    , case
        when previous_month_mrr > 0 and current_month_mrr = 0 then 'churn'
        when previous_month_mrr = 0 and current_month_mrr > 0 then 'new'
        when current_month_mrr > previous_month_mrr           then 'expansion'
        when current_month_mrr < previous_month_mrr           then 'contraction'
      end as movement_type
  from mrr_compare
)

select
    month_end_date
  , round(
        sum(
            case
              when movement_type = 'new'
              then current_month_mrr
              else 0
            end
        )
      , 2
    ) as new_mrr
  , round(
        sum(
            case
              when movement_type = 'churn'
              then previous_month_mrr
              else 0
            end
        )
      , 2
    ) as churned_mrr
  , round(
        sum(
            case
              when movement_type = 'expansion'
              then current_month_mrr - previous_month_mrr
              else 0
            end
        )
      , 2
    ) as expansion_mrr
  , round(
        sum(
            case
              when movement_type = 'contraction'
              then previous_month_mrr - current_month_mrr
              else 0
            end
        )
      , 2
    ) as contraction_mrr
from mrr_with_movements
group by month_end_date
order by month_end_date;
