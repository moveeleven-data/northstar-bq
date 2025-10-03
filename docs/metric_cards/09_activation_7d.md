# 08. Activation 7d

**status:** draft  
**owner:** product@northstar or growth@northstar  
**definition_version:** v1.0  
**last_updated:** 2025-09-21  
**sql_ref:** `sql/metrics/product/v_activation_7d.sql`  
**sources:** `northstar_app.accounts`, `northstar_app.events`  

---

## Decision

Activation 7d measures whether a new account takes a defined “activation event” within 7 days of signup.  
Product teams use this metric to track onboarding effectiveness and to measure the health of the signup funnel.  

It’s a leading indicator for conversion to paid, retention, and PQL qualification.  

---

## Grain and Population

- **Grain:** account-level, one row per account_id per signup cohort.  
- **Population:** all accounts created in the time window of interest.  

---

## Time Window

Evaluate on a rolling 7-day window from account signup date (`first_seen_date`).  

---

## Edge Cases and Rules

- Activation is defined as taking at least one qualifying product event (e.g., project created, seat invited, file uploaded).  
- Accounts with no recorded events in the first 7 days are **not activated**.  
- Late activations (after 7 days) do not count for this metric.  
- If an account cancels before day 7, it is still considered activated if the qualifying event occurred.  

---

## Formula

**Plain English:**  
For each new account, check if at least one activation event occurred within 7 days of signup. Return a binary flag and compute the cohort-level activation rate.  

**Operational:**  

- `activation_flag = 1 if exists(event where event_type in (activation_events) and event_timestamp <= signup_date + interval 7 days)`  
- Cohort activation rate = `sum(activation_flag) / count(accounts in cohort)`  

---

## Inputs and Lineage

- **accounts:** account_id, first_seen_date, cancel_date  
- **events:** account_id, event_type, event_timestamp  

---

## Default Slices

- Segment (small, mid, enterprise)  
- Region (us, eu, apac)  
- Plan_id (team, pro, usage)  

---

## Guardrails

- Each account appears once per signup date.  
- No negative or null activation flags.  
- Event-timezone alignment to UTC.  

---

## Reporting Notes

Activation rate is **non-financial**. It should be presented alongside revenue and funnel metrics, but not as a financial KPI.  

---

## Example

- 100 new accounts signed up in June.  
- 63 of them triggered at least one activation event in the first 7 days.  
- **Activation 7d rate = 63%.**  
