/*
   v_mrr_month_end.sql
   Purpose: Compute company-level and plan-level Monthly Recurring Revenue (MRR) at a given as_of_date.
   Inputs:
     - northstar_app.subscriptions: account_id, plan_id, start_date, cancel_date,
                                    seats_committed, monthly_commit_units, estimated_monthly_mrr_usd
     - northstar_app.dim_plan: plan_id, pricing_model, list_price_month, unit_rate_usd
     - northstar_app.dim_account: account_id, segment, region
   Outputs:
     - Company total: date as_of_date, active row count, distinct accounts, total MRR
     - Plan totals: plan_id, active rows, distinct accounts, total MRR, avg MRR per active account
*/

with

params as (
    select date '2025-08-30' as as_of_date
)

, active_on_as_of_date as (
    select
        account_id
      , plan_id
      , estimated_monthly_mrr_usd
    from `northstar-bq.northstar_app.subscriptions`
    cross join params
    where start_date <= as_of_date
      and (cancel_date > as_of_date or cancel_date is null)
)

-- Company total
select
    as_of_date
  , count(*) as active_rows
  , count(distinct account_id) as distinct_accounts
  , sum(estimated_monthly_mrr_usd) as total_mrr
from active_on_as_of_date
cross join params
group by as_of_date;

-- Plan totals
select
    plan_id
  , count(*) as active_rows_per_plan
  , count(distinct account_id) as distinct_accounts_per_plan
  , sum(estimated_monthly_mrr_usd) as total_mrr_per_plan
  , avg(estimated_monthly_mrr_usd) as avg_mrr_per_active_account_per_plan
from active_on_as_of_date
group by plan_id;
