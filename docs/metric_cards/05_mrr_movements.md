# 05. MRR Movements

status: draft  
owner: finance@northstar or gm@northstar  
definition_version: v1.0  
last_updated: 2025-09-19  
sql_ref: `sql/metrics/revenue/v_mrr_movements.sql`
sources: `northstar-bq.northstar_app.subscriptions`, `northstar-bq.northstar_app.dim_account`

---

## Decision
MRR Movements explain *why* total MRR changes from one month to the next. Leaders use it to distinguish true growth (new and expansion) from risk (contraction and churn). This card feeds into ARR bridges, NRR, and executive scorecards.

---

## Grain and population
- **Grain:** account-level monthly MRR snapshots.  
- **Population:** all accounts that had MRR in the current or prior month.  

---

## Time window
Evaluate at true month ends. Each row compares one month end to the previous.  

---

## Edge cases and rules
- If an account is new this month (zero before, positive now), it is **new revenue**.  
- If an account is gone this month (positive before, zero now), it is **churned revenue**.  
- If MRR increases but stays positive, it is **expansion revenue**.  
- If MRR decreases but stays positive, it is **contraction revenue**.  
- Cancel_date logic same as MRR level: active if start_date <= D and (cancel_date is null or cancel_date > D).  

---

## Formula

**Step 1. Define starting and ending MRR**
- For each account, find its `monthly_recurring_revenue` on the prior month_end_date (call this `starting_mrr`).
- Find its `monthly_recurring_revenue` on the current month_end_date (call this `ending_mrr`).
- If an account is missing in one month, treat its MRR as 0 for that side of the comparison.

**Step 2. Classify the difference**
- **New revenue:**         starting_mrr = 0 and ending_mrr > 0  
- **Churned revenue:**     starting_mrr > 0 and ending_mrr = 0  
- **Expansion revenue:**   starting_mrr > 0 and ending_mrr > starting_mrr  
- **Contraction revenue:** starting_mrr > 0 and ending_mrr < starting_mrr  

**Step 3. Reconciliation check**

For every month:  
`ending_total = starting_total + new_revenue + expansion_revenue - contraction_revenue - churned_revenue`

This identity must hold exactly. If it fails, either the active filter or the classification is off.

---

## Inputs and lineage

- **v_mrr_month_end:** gives one row per account per month_end_date, with account_id, plan_id, and monthly_recurring_revenue.  
- **dim_account:** adds segment and region for slicing.  

---

## Default slices

- plan_id (team, pro, usage)  
- segment (small, mid, enterprise)  
- region (us, eu, apac)  

Optional: ACV bands using `12 * monthly_recurring_revenue`.

---

## Guardrails

- No negative `monthly_recurring_revenue` values.  
- Every account/month must appear once.  
- Plan-level totals must equal the company total for each month.  
- Identity reconciliation (the math balances out every month) must hold for every month.

---

## Example

- Account A: 600 → 800 = +200 **expansion**  
- Account B: 500 → 0 = -500 **churn**  
- Account C: 0 → 300 = +300 **new**  
- Account D: 700 → 400 = -300 **contraction**  
- Totals: starting 1,800 → ending 1,500.  
  New + expansion - contraction - churn = 300 + 200 - 300 - 500 = -300.  
  Starting (1,800) + (-300) = 1,500, matches ending.