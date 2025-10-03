# 07. NRR Monthly

**status:** draft  
**owner:** finance@northstar or gm@northstar  
**definition_version:** v1.0  
**last_updated:** 2025-09-21  
**sql_ref:** `sql/metrics/revenue/v_nrr_monthly.sql`  
**sources:** `northstar-bq.northstar_metrics.v_mrr_movements`, `northstar_app.dim_account`  

---

## Decision

Net Revenue Retention (NRR) measures how recurring revenue from existing customers changes over time, factoring in expansion, contraction, and churn.  
It shows whether the company is growing revenue within its current customer base without relying on new customers.  

Executives use NRR as a **core health metric**: >100% indicates expansion is outpacing churn, while <100% signals net shrinkage.  

---

## Grain and Population

- **Grain:** monthly, one row per company per month_end_date (slices supported).  
- **Population:** all accounts that had recurring revenue in the starting month.  

---

## Time Window

Evaluate at true month ends. Each row compares a month end to the previous month end.  

---

## Edge Cases and Rules

- Only accounts with **starting revenue > 0** are included.  
  - This means we restrict the denominator to customers who were already active at the start of the month.  
  - New customers that generate revenue this month (starting at 0, ending > 0) are excluded because NRR is meant to measure **retention and growth within the existing base**, not growth from new logos.  
  - This distinction ensures NRR reflects the health of the installed base rather than being inflated by new sales.  
  - Example: If an account goes from $0 → $500, it contributes to **new ARR** in the bridge but not to NRR.
- Expansion, contraction, and churn follow the same definitions as in MRR Movements.  
- Formula must balance to reconciliation identity from MRR.  

---

## Formula

**Plain English:**  
NRR = (Starting revenue + Expansion − Contraction − Churn) / Starting revenue.  

**Operational:**  

- `starting_arr = sum(previous_month_mrr) * 12`  
- `expansion_arr = sum(expansion_mrr) * 12`  
- `contraction_arr = sum(contraction_mrr) * 12`  
- `churned_arr = sum(churned_mrr) * 12`  
- `nrr = (starting_arr + expansion_arr - contraction_arr - churned_arr) / starting_arr`  

---

## Inputs and Lineage

- **v_mrr_movements:** provides starting MRR, ending MRR, and movement classifications.  
- **dim_account:** adds segment and region for slicing.  

---

## Default Slices

- `plan_id` (team, pro, usage)  
- `segment` (small, mid, enterprise)  
- `region` (us, eu, apac)  

---

## Guardrails

- NRR should be bounded between 0% and >200% (values outside indicate logic issues).  
- New revenue must be excluded from numerator.  
- Totals by slice must reconcile to company total.  

---

## Reporting Notes

NRR is **non-GAAP** but is the most common SaaS retention metric used in board materials, investor reports, and internal reviews.  
It must always be presented alongside Gross Revenue Retention (GRR) for context.  

GRR: looks at starting recurring revenue and only subtracts contraction and churn.
(gross means stripped down and conservative - no credit given for upsells/expansions, capped at 100%)
(Starting MRR – Churn – Contraction) / Starting MRR

NRR: looks at starting recurring revenue, subtracts contraction and churn, and then adds expansion.
(Starting MRR – Churn – Contraction + Expansion) / Starting MRR

---

## Example

- Starting ARR: $10.0M  
- Expansion: +$1.5M  
- Contraction: −$0.3M  
- Churn: −$0.7M  

**NRR:** (10.0 + 1.5 − 0.3 − 0.7) ÷ 10.0 = 105%