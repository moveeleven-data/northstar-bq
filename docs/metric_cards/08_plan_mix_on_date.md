# 08. Plan Mix on Date

**status:** draft  
**owner:** finance@northstar or gm@northstar  
**definition_version:** v1.0  
**last_updated:** 2025-09-22  
**sql_ref:** `sql/metrics/revenue/v_plan_mix_on_date.sql`  
**sources:** `northstar-bq.northstar_metrics.v_mrr_month_end_account`, `northstar_app.dim_plan`  

---

## Decision

Plan Mix on Date shows the distribution of MRR by plan (team, pro, usage) at each month-end.  
Leaders use this metric to understand revenue concentration and how product tiers contribute to overall growth.  

---

## Grain and Population

- **Grain:** one row per `plan_id` × `month_end_date`.  
- **Population:** all accounts active at the given `month_end_date`.  

---

## Time Window

Evaluate at true month ends. Supports ad hoc dates if needed.  

---

## Edge Cases and Rules

- Only active subscriptions at the chosen date are included.  
- Plans must be mapped to valid entries in `dim_plan`.  
- Exclude free trials and one-time charges.  

---

## Formula

**Plain English:**  
At each `month_end_date`, sum the MRR for all accounts grouped by plan.  

**Operational:**  
`sum(monthly_recurring_revenue)` grouped by `month_end_date, plan_id`.  

---

## Inputs and Lineage

- **v_mrr_month_end_account:** monthly account-level MRR snapshot.  
- **dim_plan:** provides plan metadata and pricing context.  

---

## Default Slices

- `plan_id` (team, pro, usage).  
- Optional: segment, region.  

---

## Guardrails

- Totals across all plans must reconcile to company-level MRR for the same date.  
- No negative values.  

---

## Reporting Notes

Plan mix highlights strategic balance between product tiers.  
It is often shown as a stacked area or pie chart in dashboards.  
