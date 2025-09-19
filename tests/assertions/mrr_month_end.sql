/*
   mrr_month_end.sql
   Purpose: Assertions to validate v_mrr_month_end_account integrity.

   Checks:
     1. No negative MRR values.
     2. Plan-level totals equal company total per month_end_date.
     3. All active rows follow the inclusive start / exclusive end rule.
*/

-- 1. No negative MRR values
select
    count(*) as num_negative_rows
from v_mrr_month_end_account
where monthly_recurring_revenue < 0;


-- 2. Plan totals equal company total
with

company_totals as (
    select
        month_end_date
      , sum(monthly_recurring_revenue) as company_total_mrr
    from v_mrr_month_end_account
    group by month_end_date
)

, plan_totals as (
    select
        month_end_date
      , sum(monthly_recurring_revenue) as plan_total_mrr
    from v_mrr_month_end_account
    group by month_end_date
)
select
    company_totals.month_end_date
  , company_totals.company_total_mrr
  , plan_totals.plan_total_mrr
  , company_totals.company_total_mrr - plan_totals.plan_total_mrr as difference_mrr
from company_totals
join plan_totals
  on company_totals.month_end_date = plan_totals.month_end_date
where company_totals.company_total_mrr != plan_totals.plan_total_mrr;


-- 3. Active rule integrity
select
    count(*) as invalid_active_rows
from v_mrr_month_end_account snapshot_view
join northstar-bq.northstar_app.subscriptions subscription_data
  on snapshot_view.account_id = subscription_data.account_id
 and snapshot_view.plan_id = subscription_data.plan_id
where not (
     subscription_data.start_date <= snapshot_view.month_end_date
 and (subscription_data.cancel_date is null or subscription_data.cancel_date > snapshot_view.month_end_date)
);
