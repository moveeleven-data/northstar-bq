# 06. ARR Bridge

**status:** draft  
**owner:** finance@northstar or gm@northstar  
**definition_version:** v1.0  
**last_updated:** 2025-09-20  
**sql_ref:** `sql/metrics/revenue/v_arr_bridge.sql`  
**sources:** `northstar-bq.northstar_metrics.v_mrr_movements`, `northstar_app.dim_account`

---

## Decision

ARR Bridge explains how Annual Recurring Revenue changes from one month-end to the next.  
It scales MRR movements (new, expansion, contraction, churn) to annual terms and reconciles them into starting ARR and ending ARR.

Executives use the ARR Bridge to see what is driving growth (new business, upsell) versus what is eroding revenue (churn, downsell).  
It’s a standard input for board decks and fundraising.

---

## Grain and Population

- **Grain:** monthly, one row per company per month_end_date (slices supported).  
- **Population:** all accounts that were active in current or prior month.  

---

## Time Window

Evaluate at true month ends. Each row compares one month end to the previous month end.  

---

## Edge Cases and Rules

- ARR is annualized MRR: `MRR × 12`.  
- **New ARR:** starting = 0, ending > 0.  
- **Churned ARR:** starting > 0, ending = 0.  
- **Expansion ARR:** starting > 0, ending > starting.  
- **Contraction ARR:** starting > 0, ending < starting.  
- Reconciliation must hold:

```text
ending_arr = starting_arr
+ new_arr
+ expansion_arr
- contraction_arr
- churned_arr
```

---

## Formula

**Plain English:**  
Take `v_mrr_movements`, multiply each bucket by 12, then sum at the company or slice level.  

**Operational:**  

- `starting_arr = sum(previous_month_mrr) * 12`  
- `ending_arr = sum(current_month_mrr) * 12`  
- `new_arr = sum(new_mrr) * 12`  
- `churned_arr = sum(churned_mrr) * 12`  
- `expansion_arr = sum(expansion_mrr) * 12`  
- `contraction_arr = sum(contraction_mrr) * 12`  

---

## Inputs and Lineage

- **v_mrr_movements:** account-level monthly MRR movements.  
- **dim_account:** adds slices like segment and region.  

---

## Default Slices

- `plan_id` (team, pro, usage)  
- `segment` (small, mid, enterprise)  
- `region` (us, eu, apac)  
- Optional ACV bands  

---

## Guardrails

- No negative ARR values.  
- Totals by slice must sum to company total.  
- Reconciliation identity must hold each month.  

---

## Reporting Notes

ARR Bridge is **non-GAAP**. It should be presented alongside GAAP revenue with clear explanation of differences (e.g., one-time services, credits).  

---

## Example

- April ending ARR: $12.0M  
- May ending ARR: $13.1M  

**Bridge:**  
- +$0.8M new  
- +$0.6M expansion  
- −$0.2M contraction  
- −$0.1M churn  

**Check:** 12.0 + 0.8 + 0.6 − 0.2 − 0.1 = 13.1
