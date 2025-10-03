# 04. MRR (Monthly Recurring Revenue)

**status:** production  
**owner:** finance@northstar or gm@northstar  
**definition_version:** v1.0  
**last_updated:** 2025-09-19  
**sql_ref:** `sql/metrics/revenue/mrr_point_in_time.sql`  
**tests_ref:** `tests/assertions/mrr_reconciliation.sql`  
**sources:** `northstar_app.subscriptions`, `northstar_app.dim_plan`, `northstar_app.dim_account`

---

## Decision

MRR shows the company’s **recurring revenue run rate** (the amount of recurring revenue right now, projected 
forward as if today’s subscriptions continued unchanged). It is measured at a point in time, typically month end.  

Leaders use MRR to understand the **level, mix, and short-term trajectory** of revenue, and to guide hiring and spending decisions.  

---

## Grain and Population
- **Grain:** subscription row  
- **Population:** all active subscriptions on date `as_of_date`. In this dataset, one row per account.

---

## Time Window
Evaluate on true month ends (last calendar day of each month). Ad hoc dates are supported but not standard.

---

## Edge Cases and Rules
- Exclude free trials, one-time fees, and services  
- Credits affect invoices, not MRR, unless they permanently lower recurring price  
- Active if `start_date <= as_of_date` and (`cancel_date is null or cancel_date > as_of_date`)  
- If `cancel_date = as_of_date`, not active on `as_of_date`  
- Currency: USD only  
- One subscription per account in this dataset  

---

## Formula
**Plain English:**  
MRR on date `as_of_date` is the sum of monthly subscription amounts for all rows active on `as_of_date`.  

**Operational:**  
`sum(estimated_monthly_mrr_usd)` where `start_date <= as_of_date` and (`cancel_date is null or cancel_date > as_of_date`).  

**Derivation of `estimated_monthly_mrr_usd`:**  
- team = `seats_committed * 20.00`  
- pro = `seats_committed * 50.00`  
- usage = `monthly_commit_units * 0.02`  

These are precomputed in `northstar_app.subscriptions`.

---

## Inputs and Lineage
- **Subscriptions:** `account_id`, `plan_id`, `start_date`, `cancel_date`, seats/units, `estimated_monthly_mrr_usd`  
- **Plans:** `plan_id`, `pricing_model`, `list_price_month`, `unit_rate_usd`  
- **Accounts:** `account_id`, `segment`, `region`  

---

## Default Slices
- `plan_id` (team, pro, usage)  
- `segment` (small, mid, enterprise)  
- `region` (us, eu, apac)  
- Optional ACV bands (`12 * estimated_monthly_mrr_usd`)

---

## Guardrails
- No negative MRR values  
- Referential integrity: all `plan_id` in `dim_plan`, all `account_id` in `dim_account`  
- Reconciliation identity (for later movements):  
  `ending MRR = starting MRR + new + expansion - contraction - churn`  
- Sanity: plan-level sums must equal company total  
- Check that seat and usage plans match their pricing formulas  

---

## Reporting Notes
MRR is **non-GAAP**. Always state definition. Reconcile separately to GAAP revenue, explaining differences (e.g., deferrals, credits).

MRR = “Where am I sitting today?” (net of everything that happened before now).
NRR = “How well did I retain and grow the dollars I had at the start of the month?”

---

## Example
- Pro plan, 12 seats × $50 = $600 MRR. Active if `start_date <= D` and no cancel before `as_of_date`.  
- Usage plan, 6,500 units × $0.02 = $130 MRR. Same active rule.