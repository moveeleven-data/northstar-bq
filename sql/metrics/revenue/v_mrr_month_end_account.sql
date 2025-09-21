/*
   v_mrr_month_end_account.sql
   Purpose: Provide account-level snapshots of Monthly Recurring Revenue (MRR) at true month ends.
            Serves as the foundation for movement analysis, ARR bridges, and retention metrics.

   Inputs:
     - northstar_app.subscriptions:
         account_id, plan_id, start_date, cancel_date,
         seats_committed, monthly_commit_units, estimated_monthly_mrr_usd
     - (optional enrichments) northstar_app.dim_plan and northstar_app.dim_account

   Outputs:
     - One row per account per month_end_date with:
         month_start_date
         month_end_date
         account_id
         plan_id
         monthly_recurring_revenue (from estimated_monthly_mrr_usd)

   Notes:
     - Active if start_date <= month_end_date and (cancel_date is null or cancel_date > month_end_date).
     - Inclusive start, exclusive end logic for activity.
     - This view is the base for v_mrr_movements.sql.
*/

with

month_ends as (
    select
        date_trunc(month_date, month) as month_start_date,
        last_day(month_date, month) as month_end_date
    from unnest(
        generate_date_array(
            (select min(start_date) from `northstar-bq.northstar_app.subscriptions`),
            (select coalesce(max(cancel_date), current_date()) from `northstar-bq.northstar_app.subscriptions`),
            interval 1 month
        )
    ) as month_date
)

, mrr_combined as (
    select
        month_start_date
      , month_end_date
      , account_id
      , plan_id
      , estimated_monthly_mrr_usd as monthly_recurring_revenue
    from `northstar-bq.northstar_app.subscriptions`
    cross join month_ends
    where start_date <= month_end_date
      and (cancel_date > month_end_date or cancel_date is null)
)

select
    month_start_date
  , month_end_date
  , account_id
  , plan_id
  , monthly_recurring_revenue
from mrr_combined;
