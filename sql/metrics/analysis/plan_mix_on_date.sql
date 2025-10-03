/*
   v_plan_mix_on_date.sql
   Purpose: Show monthly MRR distribution by plan, to analyze revenue mix across product lines.
            Aggregates current_month_mrr from v_mrr_movements, grouped by plan and month_end_date.

   Inputs:
     - v_mrr_movements: account_id, plan_id, month_end_date, current_month_mrr
     - dim_plan: plan_id, plan_name

   Outputs:
     - One row per plan_id per month_end_date with total MRR
     - Used to track plan-level revenue share and product mix trends
*/

select
    month_end_date
  , plan_name
  , sum(current_month_mrr) as total_mrr
from `northstar-bq.northstar_metrics.v_mrr_movements`
inner join `northstar-bq.northstar_app.dim_plan` using (plan_id)
group by
    month_end_date
  , plan_name;
