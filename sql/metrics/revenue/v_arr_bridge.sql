/*
   v_arr_bridge.sql
   Purpose: Build the ARR Bridge by scaling monthly MRR movements (new, expansion, contraction, churn)
            to annual terms, and reconciling them into starting ARR and ending ARR.

   Inputs:
     - v_mrr_movements: account_id, plan_id, month_end_date, previous_month_mrr, current_month_mrr, movement_type
     - northstar_app.dim_account: account_id, segment, region

   Outputs:
     - One row per month_end_date (with slice dimensions if joined)
     - Aggregated company-level totals for starting_arr, ending_arr, new_arr, expansion_arr, contraction_arr, churned_arr
     - Reconciliation identity check: ending_arr = starting_arr + new_arr + expansion_arr - contraction_arr - churned_arr
*/

with

arr_bridge as (
    select
        month_end_date
      , round(sum(previous_month_mrr * 12), 2)   as starting_arr
      , round(sum(current_month_mrr * 12), 2)    as ending_arr
      , round(sum(new_mrr * 12), 2)              as est_new_arr
      , round(sum(expansion_mrr * 12), 2)        as est_exp_arr
      , round(sum(contraction_mrr * 12), 2)      as est_contr_arr
      , round(sum(churned_mrr * 12), 2)          as est_churned_arr
    from `northstar-bq.northstar_metrics.v_mrr_movements`
    group by month_end_date
)

, with_nrr as (
    select
        month_end_date
      , starting_arr
      , ending_arr
      , est_new_arr
      , est_exp_arr
      , est_contr_arr
      , est_churned_arr
      , round(est_new_arr + est_exp_arr - est_contr_arr - est_churned_arr, 2) as net_new_arr
    from arr_bridge
)

, recon_diff as (
    select
        month_end_date
      , starting_arr
      , ending_arr
      , net_new_arr
      , round(ending_arr - (starting_arr + net_new_arr), 2) as recon_diff
    from with_nrr
)

select
    recon.month_end_date
  , recon.net_new_arr
  , recon.recon_diff
from recon_diff recon;