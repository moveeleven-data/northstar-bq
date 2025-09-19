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

