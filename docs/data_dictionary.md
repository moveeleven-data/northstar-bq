# Northstar-BQ Data Dictionary

This document defines every dataset, table, column, and derived view in your BigQuery project. It is written for analytics engineering usage, with precise semantics, generation logic, and guardrails.

## Scope and conventions

### Project and location
**Project:** `northstar-bq`  
**Datasets:** `northstar_app`, `northstar_metrics`  
**Location:** `US` for all datasets and jobs

### Time
- **date** columns are calendar dates, no time zone  
- **timestamp** columns are UTC

### Month keys
- `month_start_date` is the first calendar day of a month  
- `month_end_date` is the last calendar day of a month

### Currency
All monetary fields are USD. No FX logic is applied.

### IDs and natural keys
- `account_id` like `A0123`  
- `user_id` like `U000157`  
- `opportunity_id` like `O000241`  
- `ticket_id` like `T0010023`  

BigQuery does not enforce uniqueness. Treat these as unique by convention.

### Nulls
Nulls are meaningful. Example: `cancel_date` null means an active subscription as of the evaluated date.

### Row volumes (first build, typical)

| table              | approx rows                |
|--------------------|----------------------------|
| dim_account        | about 500                  |
| dim_user           | about 1,700 to 2,500       |
| fact_subscriptions | about 500                  |
| fact_usage_daily   | tens of thousands          |
| fact_product_events| about 25k to 35k           |
| fact_invoices      | hundreds to a few thousand |
| fact_opportunities | hundreds to a few thousand |
| fact_tickets       | hundreds to a few thousand |

### Partitioning and clustering
Base tables are unpartitioned for simplicity. If you outgrow the free tier, consider partitioning large facts by date columns, for example `usage_date` or `event_timestamp`.

## Dataset: `northstar_app`

Synthetic source-like entities and facts for a B2B SaaS.

---

### Table: `dim_calendar_day`

| column | type | required | description | example |
|--------|------|----------|-------------|---------|
| day    | date | yes      | One row per calendar day for the past about 730 days through today | 2025-09-18 |

**Generation**  
`generate_date_array(date_sub(current_date(), interval 730 day), current_date())`

**Use**  
Join driver for expanding windows, month derivations, and completeness checks.

---

### Table: `dim_plan`

| column          | type    | required | description                  | allowed values        | example |
|-----------------|---------|----------|------------------------------|-----------------------|---------|
| plan_id         | string  | yes      | Plan code                    | free, team, pro, usage| team    |
| plan_name       | string  | yes      | Human name                   |                       | Team    |
| pricing_model   | string  | yes      | Charge model                 | seat, usage           | seat    |
| list_price_month| float64 | yes      | List price per month for seat plans | non negative | 20.00  |
| unit_rate_usd   | float64 | nullable | Unit price for usage plan    | non negative or null  | 0.02    |

**Notes**  
Seat plans use `list_price_month`. Usage plan uses `unit_rate_usd`.

---

### Table: `dim_account`

| column          | type   | required | description                             | example    |
|-----------------|--------|----------|-----------------------------------------|------------|
| account_id      | string | yes      | Primary key                             | A0042      |
| segment         | string | yes      | Size band                               | small, mid, enterprise |
| region          | string | yes      | Primary region                          | us, eu, apac |
| first_seen_date | date   | yes      | First touch or inferred acquisition date| 2024-12-05 |

**Generation**  
500 accounts. Segments about 35% small, 50% mid, 15% enterprise. Regions about 50% US, 25% EU, 25% APAC. Dates spread across roughly 18 months.

---

### Table: `dim_user`

| column       | type   | required | description                 | example |
|--------------|--------|----------|-----------------------------|---------|
| user_id      | string | yes      | Primary key                 | U001532 |
| account_id   | string | yes      | FK to `dim_account.account_id` | A0198 |
| role         | string | yes      | App role                    | admin or member |
| created_date | date   | yes      | First seen date for user    | 2025-03-12 |

**Generation**  
About 2 to 4 users per account, skewed slightly to admins.

---

### Table: `fact_subscriptions`

One subscription record per account with a single active plan at a time, used for MRR and ARR.

| column                   | type    | required | description                       | example   |
|--------------------------|---------|----------|-----------------------------------|-----------|
| account_id               | string  | yes      | FK to `dim_account`               | A0301     |
| plan_id                  | string  | yes      | FK to `dim_plan`                  | pro       |
| start_date               | date    | yes      | Subscription start                | 2024-11-07|
| cancel_date              | date    | nullable | End date if canceled              | 2025-06-10 or null |
| seats_committed          | int64   | nullable | Seats for seat plans              | 12        |
| monthly_commit_units     | int64   | nullable | Commit for usage plan             | 6500      |
| estimated_monthly_mrr_usd| float64 | yes      | Normalized monthly recurring revenue | 600.00 |

**Semantics**  
- Exactly one row per account in this synthetic set.
- “Company X, on Plan Y, starting at Date Z, contributes $N in recurring subscription revenue every month until the 
  cancel date (or indefinitely if cancel is null).”

**estimated_monthly_mrr_usd derivation**  
- team: `seats_committed * 20.00`  
- pro: `seats_committed * 50.00`  
- usage: `monthly_commit_units * 0.02`  

**Activity flag**  
Active on date `d` if `d between start_date and coalesce(cancel_date, d)`.

**Notes**
- Monthly MRR is constant here until you introduce adjustments or step ups.
- In this dataset, an account represents a company or organization, not an individual person.
- The plan is the subscription package an account buys.
- Seats committed is the number of user licenses (seats) that the account has committed to pay for each month.
- Monthly commit units is the amount of usage an account has committed to pay for each month. Could be API calls, 
  data storage, or jobs run.

### Table: `fact_usage_daily`

Daily usage and product feature signals at the account level.

| column        | type   | required | description                          | example   |
|---------------|--------|----------|--------------------------------------|-----------|
| account_id    | string | yes      | FK to `dim_account`                  | A0441     |
| plan_id       | string | yes      | Denormalized plan on that day        | usage     |
| usage_date    | date   | yes      | Activity day                         | 2025-06-14|
| billable_units| int64  | yes      | Daily billable units                 | 142       |
| feature_events| int64  | yes      | App feature event count              | 387       |
| api_error_flag| bool   | yes      | Whether an API error occurred that day | false   |

**Generation**  
Rows exist for a subset of active days, about 55 percent, to mimic sparsity. Usage ranges differ by plan, usage highest, team lowest.

**Use**  
Operational health, simple pre-churn heuristics, consumption analysis.

---

### Table: `fact_product_events`

Event stream at user grain for funnels, activation, and PQL definitions.

| column          | type      | required | description       | allowed values                                                                 | example                    |
|-----------------|-----------|----------|-------------------|--------------------------------------------------------------------------------|----------------------------|
| event_timestamp | timestamp | yes      | UTC event time    |                                                                                | 2025-08-07 13:25:04 UTC    |
| account_id      | string    | yes      | FK to `dim_account` |                                                                                | A0207                      |
| user_id         | string    | yes      | FK to `dim_user`  |                                                                                | U000923                    |
| event_name      | string    | yes      | Event category    | signup, project_create, invite_sent, file_upload, job_run, api_call, paywall_view, subscribe_click | subscribe_click |

**Generation**  
User days are downsampled to about 10 percent. Each user day is given a deterministic score `r` based on `farm_fingerprint(user_id || ':' || event_date)` scaled to `[0, 1)`. Mapping by score:  
- `r < 0.12`: signup  
- `0.12 <= r < 0.30`: project_create  
- `0.30 <= r < 0.45`: invite_sent  
- `0.45 <= r < 0.65`: file_upload  
- `0.65 <= r < 0.80`: job_run  
- `0.80 <= r < 0.92`: api_call  
- `0.92 <= r < 0.97`: paywall_view  
- `0.97 <= r`: subscribe_click  

This yields stable proportions and guarantees presence of signups and subscribe clicks.

**Use**  
Activation analysis, PQL windows, lightweight funnels.

---

### Table: `fact_invoices`

Monthly invoices derived from active subscription months.

| column             | type    | required | description                  | example   |
|--------------------|---------|----------|------------------------------|-----------|
| invoice_month      | date    | yes      | First day of the invoice month | 2025-09-01 |
| account_id         | string  | yes      | FK to `dim_account`          | A0191     |
| plan_id            | string  | yes      | Plan billed                  | usage     |
| invoice_amount_usd | float64 | yes      | Billed amount for the month  | 512.38    |
| credit_amount_usd  | float64 | yes      | Credits applied in the month | 8.25      |

**Generation**  
Enumerates months between `start_date` and `cancel_date` (or current month). Usage invoices vary 70 percent to 150 percent of estimated MRR. Seat invoices vary about 95 percent to 115 percent. Random credits about 3 percent of months.

**Use**  
Cash timing, variance vs MRR, credit policy effects.

---

### Table: `fact_opportunities`

Simple sales pipeline per opportunity.

| column         | type    | required | description        | allowed values                          | example   |
|----------------|---------|----------|--------------------|-----------------------------------------|-----------|
| opportunity_id | string  | yes      | Primary key        |                                         | O000241   |
| account_id     | string  | yes      | FK to `dim_account`|                                         | A0098     |
| source         | string  | yes      | Lead source        | inbound, outbound, partner              | inbound   |
| stage          | string  | yes      | Pipeline stage     | discovery, evaluation, procurement, won, lost | evaluation |
| amount_usd     | float64 | yes      | Opportunity amount |                                         | 28450.00  |
| created_date   | date    | yes      | Created date       |                                         | 2025-03-04|
| closed_date    | date    | nullable | Close date if won or lost |                                         | 2025-06-10 or null |

**Notes**  
Stages assigned at creation. `closed_date` populated only when `stage in ('won','lost')`. Random selection can produce few won or lost in a single run. If you want guaranteed outcomes, add a small post process to assign outcomes for a fixed fraction of open stages.

### Table: `fact_tickets`

Support tickets for health and risk signals.

| column          | type   | required | description       | allowed values                            | example   |
|-----------------|--------|----------|-------------------|-------------------------------------------|-----------|
| ticket_id       | string | yes      | Primary key       |                                           | T0001023  |
| account_id      | string | yes      | FK to `dim_account` |                                         | A0333     |
| category        | string | yes      | Ticket category   | billing, onboarding, bug, how_to, feature_request | bug |
| opened_date     | date   | yes      | Opened date       |                                           | 2025-07-02|
| resolved_date   | date   | nullable | Resolved date     |                                           | 2025-07-05 or null |
| csat_score_1_5  | int64  | nullable | CSAT when resolved| 1..5 or null                              | 4         |

**Generation**  
Categories normalized with a deterministic hash so distribution is balanced. About 85 percent of tickets resolve within 1 to 14 days. CSAT exists only when resolved.

---

## Dataset: `northstar_metrics` (views)

Thin, queryable views for recurring revenue and product-led signals. Standard views, not materialized.

---

### View: `v_mrr_month_end`

Month end MRR at account and plan grain, with stable month keys.

| column                   | type    | description                               |
|--------------------------|---------|-------------------------------------------|
| month_start_date         | date    | First day of month                        |
| month_end_date           | date    | Last day of month                         |
| account_id               | string  | Account                                   |
| plan_id                  | string  | Plan at month end                         |
| monthly_recurring_revenue| float64 | Normalized MRR for that account and month |

**Definition**  
Builds a distinct month calendar from `northstar_app.dim_calendar_day`. Flags subscriptions active at `month_end_date`. Sums to monthly MRR per account.

**Use**  
Single source of truth for MRR and ARR level. Always aggregate from this view.

---

### View: `v_mrr_movements`

Month over month MRR classification per account.

| column                   | type    | description                                   |
|--------------------------|---------|-----------------------------------------------|
| month_start_date         | date    | Current month start                           |
| account_id               | string  | Account                                       |
| previous_monthly_revenue | float64 | Prior month MRR, zero if none                 |
| current_monthly_revenue  | float64 | Current month MRR, zero if none               |
| new_revenue              | float64 | MRR from net new accounts, previous zero and current positive |
| expansion_revenue        | float64 | Increase on existing accounts                 |
| contraction_revenue      | float64 | Decrease on existing accounts, still positive |
| churned_revenue          | float64 | Lost MRR from accounts going to zero          |

**Guardrails**  
Reconciliation identity holds by design:  
`ending = starting + new + expansion - contraction - churn`.

---

### View: `v_arr_bridge`

ARR components derived from monthly movements.

| column           | type    | description                         |
|------------------|---------|-------------------------------------|
| month_start_date | date    | Current month start                 |
| new_arr          | float64 | `12 * new_revenue`                  |
| expansion_arr    | float64 | `12 * expansion_revenue`            |
| contraction_arr  | float64 | `12 * contraction_revenue`          |
| churned_arr      | float64 | `12 * churned_revenue`              |
| ending_arr       | float64 | `12 * sum(current_monthly_revenue)` |

**Use**  
Board style bridges. Keep periods contiguous. Always show absolute Net New ARR next to rates.

---

### View: `v_nrr_monthly`

Net revenue retention across existing accounts only.

| column            | type    | description                                           |
|-------------------|---------|-------------------------------------------------------|
| month_start_date  | date    | Current month start                                   |
| starting_mrr      | float64 | Sum of prior month MRR for existing accounts          |
| expansion_revenue | float64 | Expansion on those accounts                           |
| contraction_revenue| float64| Contraction on those accounts                         |
| churned_revenue   | float64 | Churn on those accounts                               |
| nrr               | float64 | `(starting - contraction - churn + expansion) / starting` |

**Notes**  
Excludes net new from the denominator by definition. In this synthetic set, expansion may be small until you introduce adjustments.

---

### View: `v_activation_7d`

Signup to activation within 7 days at user cohort month.

| column            | type      | description                                                                 |
|-------------------|-----------|-----------------------------------------------------------------------------|
| signup_month      | timestamp | Month of the first signup event for the user, UTC truncated to month        |
| signups           | int64     | Users with a first signup in the month                                      |
| activated_7d      | int64     | Those users who did `project_create` or `file_upload` or `job_run` within 7 days |
| activation_rate_7d| float64   | `activated_7d / signups`                                                    |

**Signals**  
Sensitive to event sparsity. The event generator guarantees enough signups to keep this stable.

---

### View: `v_pql_accounts`

PQL accounts by month using a simple and defendable rule.

| column     | type      | description                              |
|------------|-----------|------------------------------------------|
| account_id | string    | Account that reached PQL                 |
| pql_month  | timestamp | Month when PQL condition first met        |

**Rule**  
Measure a 28 day window from the first signup at the account. PQL if either:  
- At least one `subscribe_click`, or  
- At least three total `job_run` or `api_call` events

---

## Lineage summary

- `northstar_app.*` are base tables  
- `northstar_metrics.v_mrr_month_end` reads `northstar_app.fact_subscriptions` and `northstar_app.dim_calendar_day`  
- `northstar_metrics.v_mrr_movements` reads `v_mrr_month_end`  
- `northstar_metrics.v_arr_bridge` and `v_nrr_monthly` read `v_mrr_movements`  
- `northstar_metrics.v_activation_7d` and `v_pql_accounts` read `northstar_app.fact_product_events`

---

## Known modeling choices and pitfalls

- Single subscription per account in this seed. If you later simulate multi product or multi plan, adjust `v_mrr_month_end` to sum across products, and keep movements at the account level.  
- Constant MRR unless you add adjustments or ramps. Expansion and contraction will be limited until you do.  
- Sparse daily usage. `fact_usage_daily` omits many days by design. Do not treat missing rows as zero without a left join and `coalesce`.  
- Event downsampling. `fact_product_events` is a sample of user days. Rates and funnels are indicative.  
- Invoices vs MRR. Invoices vary around MRR, especially for usage plans. Do not compute MRR from invoices.
