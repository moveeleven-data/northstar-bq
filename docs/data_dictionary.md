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

| column           | type    | required | description                                    | allowed values           | example |
|------------------|---------|----------|------------------------------------------------|--------------------------|---------|
| plan_id          | string  | yes      | System code for the plan                       | free, team, pro, usage   | team    |
| plan_name        | string  | yes      | Human-readable plan name                       |                          | Team    |
| pricing_model    | string  | yes      | How the plan charges                           | seat, usage              | seat    |
| list_price_month | float64 | yes      | Price per seat per month (for seat plans)      | non-negative             | 20.00   |
| unit_rate_usd    | float64 | nullable | Price per usage unit (for usage-based plans)   | non-negative or null     | 0.02    |

**Description**  
`dim_plan` defines the subscription products offered by the company. Each plan has a unique code and name, and a pricing model that determines how recurring revenue is calculated. Seat-based plans use `list_price_month` multiplied by seats committed, while usage-based plans use `unit_rate_usd` multiplied by monthly committed units. This table is central to deriving MRR and ARR, since it provides the baseline pricing logic for all subscriptions.

**Notes**  
- Seat plans calculate revenue as `seats_committed * list_price_month`.  
- Usage plans calculate revenue as `monthly_commit_units * unit_rate_usd`.  
- Free plan has no charge (MRR = 0).

---

### Table: `dim_account`

| column          | type   | required | description                               | example    |
|-----------------|--------|----------|-------------------------------------------|------------|
| account_id      | string | yes      | Unique identifier for each customer account | A0042      |
| segment         | string | yes      | Account size classification               | small, mid, enterprise |
| region          | string | yes      | Primary geographic region                 | us, eu, apac |
| first_seen_date | date   | yes      | Acquisition or first observed date        | 2024-12-05 |

**Description**  
`dim_account` represents the companies (customers) that subscribe to the product. Each account has a unique identifier, belongs to a size segment, and operates in a primary region. The `first_seen_date` indicates when the customer first appeared in the system, either through acquisition or initial activity. This table anchors all subscription, usage, and revenue data, allowing MRR and movements to be sliced by customer segment and geography for business reporting.

**Generation**  
- Total of about 500 accounts.  
- Segment mix: ~35% small, ~50% mid, ~15% enterprise.  
- Region mix: ~50% US, ~25% EU, ~25% APAC.  
- Acquisition dates distributed across ~18 months.  

---

### Table: `dim_user`

| column       | type   | required | description                           | example |
|--------------|--------|----------|---------------------------------------|---------|
| user_id      | string | yes      | Unique identifier for the user         | U001532 |
| account_id   | string | yes      | Foreign key to `dim_account.account_id`| A0198   |
| role         | string | yes      | Application role                      | admin, member |
| created_date | date   | yes      | Date the user was first observed       | 2025-03-12 |

**Description**  
`dim_user` captures the individual users associated with each customer account. Every user belongs to an account and is assigned a role, typically admin or member, that determines their access within the product. This table supports analyses of adoption, activation, and engagement at the user level while still tying activity back to the account level for revenue and retention reporting.

**Generation**  
About 2 to 4 users per account, skewed slightly to admins.

---

### Table: `fact_subscriptions`

One subscription record per account with a single active plan at a time, used for MRR and ARR.

| column                   | type    | required | description                                | example   |
|--------------------------|---------|----------|--------------------------------------------|-----------|
| account_id               | string  | yes      | Foreign key to `dim_account`               | A0301     |
| plan_id                  | string  | yes      | Foreign key to `dim_plan`                  | pro       |
| start_date               | date    | yes      | Subscription start date                    | 2024-11-07|
| cancel_date              | date    | nullable | End date if canceled                       | 2025-06-10 or null |
| seats_committed          | int64   | nullable | Number of seats for seat-based plans       | 12        |
| monthly_commit_units     | int64   | nullable | Monthly commit units for usage-based plans | 6500      |
| estimated_monthly_mrr_usd| float64 | yes      | Normalized recurring monthly revenue       | 600.00    |

**Description**  
`fact_subscriptions` is the central revenue-driving fact table. Each row represents one account’s active subscription to a plan, with start and cancel dates defining its lifecycle. Depending on the pricing model, subscriptions may be based on committed seats or usage units, both normalized into `estimated_monthly_mrr_usd` for comparability. This table provides the foundation for all recurring revenue calculations, including MRR, ARR, churn, and expansion, and ties directly to `dim_account` and `dim_plan` for segmentation.

**Semantics**  
- Exactly one row per account in this synthetic set.
- “Company X, on Plan Y, starting at Date Z, contributes $N in recurring subscription revenue every month until the 
  cancel date (or indefinitely if cancel is null).”

**estimated_monthly_mrr_usd derivation**  
- team: `seats_committed * 20.00`  
- pro: `seats_committed * 50.00`  
- usage: `monthly_commit_units * 0.02`  

**Activity flag**  
Active on date `as_of_date` if `as_of_date between start_date and coalesce(cancel_date, as_of_date)`.

**Notes**
- Monthly MRR is constant here until you introduce adjustments or step ups (for example, seat increases, pricing changes, or usage re-commits).  
- In this dataset, an account represents a company or organization, not an individual person.
- The plan is the subscription package an account buys.
- Seats committed is the number of user licenses (seats) that the account has committed to pay for each month.
- Monthly commit units is the amount of usage an account has committed to pay for each month. Could be API calls, 
  data storage, or jobs run.

---

### Table: `fact_usage_daily`

Daily usage and product feature activity recorded at the account level.

| column        | type   | required | description                                                                 | example   |
|---------------|--------|----------|-----------------------------------------------------------------------------|-----------|
| account_id    | string | yes      | Foreign key to `dim_account`, identifies which customer the usage belongs to | A0441     |
| plan_id       | string | yes      | Plan associated with the account on that day (denormalized for convenience)  | usage     |
| usage_date    | date   | yes      | Calendar date of the recorded activity                                      | 2025-06-14|
| billable_units| int64  | yes      | Number of consumption units that are billable (e.g. API calls, storage)     | 142       |
| feature_events| int64  | yes      | Count of product feature events performed by users in the account           | 387       |
| api_error_flag| bool   | yes      | True if the account experienced at least one API error on that day          | false     |

**Description**  
`fact_usage_daily` captures how each account interacts with the product on a specific day. It combines **billable usage** (units that directly tie to revenue for usage-based plans) with **behavioral signals** (feature events that show engagement). The `api_error_flag` highlights operational health issues. Together, these fields support product analytics, risk monitoring, and consumption-based revenue analysis.

**Generation**  
Rows exist for a subset of active days, about 55 percent, to mimic sparsity. Usage ranges differ by plan, usage highest, team lowest.

**Use**  
Operational health, simple pre-churn heuristics, consumption analysis.

---

### Table: `fact_product_events`

Stream of product usage events at the **user** grain, used to analyze funnels, activation, and PQL (product-qualified lead) signals.

| column          | type      | required | description                                                                 | allowed values                                                                 | example                  |
|-----------------|-----------|----------|-----------------------------------------------------------------------------|--------------------------------------------------------------------------------|--------------------------|
| event_timestamp | timestamp | yes      | Exact time of the event in UTC                                              |                                                                                | 2025-08-07 13:25:04 UTC  |
| account_id      | string    | yes      | Foreign key to `dim_account`, identifies the customer associated with event |                                                                                | A0207                    |
| user_id         | string    | yes      | Foreign key to `dim_user`, identifies the individual user who triggered it  |                                                                                | U000923                  |
| event_name      | string    | yes      | Category of event                                                           | signup, project_create, invite_sent, file_upload, job_run, api_call, paywall_view, subscribe_click | subscribe_click |

**Description**  
`fact_product_events` captures every significant action performed by users in the application. It provides the raw signal for understanding engagement patterns, building funnels, and defining activation or PQL criteria. Events are standardized into a small set of categories such as signups, invites, uploads, and API calls, making them suitable for consistent analysis across accounts and cohorts. Because it sits at the **user level**, this table connects adoption behavior back to accounts for growth and retention metrics.

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

Represents billing activity at the **monthly account-plan grain**, derived from active subscription months. Used to track cash timing, credits, and variance relative to MRR.

| column             | type    | required | description                                      | example   |
|--------------------|---------|----------|--------------------------------------------------|-----------|
| invoice_month      | date    | yes      | First calendar day of the invoice month          | 2025-09-01 |
| account_id         | string  | yes      | Foreign key to `dim_account`, billed customer    | A0191     |
| plan_id            | string  | yes      | Plan that generated the invoice                  | usage     |
| invoice_amount_usd | float64 | yes      | Total billed amount for that month (before credits) | 512.38    |
| credit_amount_usd  | float64 | yes      | Credits or adjustments applied to the invoice    | 8.25      |

**Description**  
`fact_invoices` captures the actual monthly billing output of the system. While MRR provides a normalized view of recurring revenue, invoices reflect what was charged and collected, including natural variability and credits. Seat plans typically bill close to the estimated MRR, while usage plans fluctuate depending on actual consumption. Credits reduce invoice totals but do not change recurring run rate unless they represent a permanent adjustment.

**Generation**  
Enumerates months between `start_date` and `cancel_date` (or current month). Usage invoices vary 70 percent to 150 percent of estimated MRR. Seat invoices vary about 95 percent to 115 percent. Random credits about 3 percent of months.

**Use**  
Cash timing, variance vs MRR, credit policy effects.

---

### Table: `fact_opportunities`

Represents the **sales pipeline** at the opportunity level, capturing sourcing, stage progression, and deal value. Each row is a distinct opportunity tied to an account.

| column         | type    | required | description                          | allowed values                          | example   |
|----------------|---------|----------|--------------------------------------|-----------------------------------------|-----------|
| opportunity_id | string  | yes      | Primary key for the opportunity      |                                         | O000241   |
| account_id     | string  | yes      | Foreign key to `dim_account`         |                                         | A0098     |
| source         | string  | yes      | How the opportunity originated       | inbound, outbound, partner              | inbound   |
| stage          | string  | yes      | Current pipeline stage               | discovery, evaluation, procurement, won, lost | evaluation |
| amount_usd     | float64 | yes      | Potential or actual deal value       |                                         | 28450.00  |
| created_date   | date    | yes      | Date the opportunity was created     |                                         | 2025-03-04|
| closed_date    | date    | nullable | Date closed if stage is won or lost  |                                         | 2025-06-10 or null |

**Description**  
`fact_opportunities` is the forward-looking view of revenue. Opportunities progress through pipeline stages until they are either won or lost. The `amount_usd` reflects the deal’s expected or actual value. This table connects sales activity with revenue forecasts and helps track conversion rates, pipeline health, and sourcing effectiveness.

**Notes**  
Stages assigned at creation. `closed_date` populated only when `stage in ('won','lost')`. Random selection can produce few won or lost in a single run. If you want guaranteed outcomes, add a small post process to assign outcomes for a fixed fraction of open stages.

### Table: `fact_tickets`

Tracks **customer support tickets** raised by accounts. Each row represents one ticket from opening through resolution, including customer satisfaction feedback when available.

| column          | type   | required | description                           | allowed values                            | example   |
|-----------------|--------|----------|---------------------------------------|-------------------------------------------|-----------|
| ticket_id       | string | yes      | Primary key for the support ticket    |                                           | T0001023  |
| account_id      | string | yes      | Foreign key to `dim_account`          |                                           | A0333     |
| category        | string | yes      | Type of issue reported                | billing, onboarding, bug, how_to, feature_request | bug |
| opened_date     | date   | yes      | Date the ticket was opened            |                                           | 2025-07-02|
| resolved_date   | date   | nullable | Date the ticket was resolved (if any) |                                           | 2025-07-05 or null |
| csat_score_1_5  | int64  | nullable | Customer satisfaction score at close  | 1–5 or null                               | 4         |

**Description**  
`fact_tickets` provides a record of customer-reported issues and their outcomes. Categories capture the nature of the request (from billing to feature requests). Resolution dates indicate support responsiveness, while `csat_score_1_5` offers a direct measure of customer satisfaction. This table is key for monitoring account health, identifying systemic product issues, and quantifying risk signals tied to churn or expansion opportunities.

**Generation**  
Categories normalized with a deterministic hash so distribution is balanced. About 85 percent of tickets resolve within 1 to 14 days. CSAT exists only when resolved.

---

## Dataset: `northstar_metrics` (views)

Thin, queryable views for recurring revenue and product-led signals. Standard views, not materialized.

---

### View: `v_mrr_month_end`

Captures normalized MRR snapshots at month end, at account and plan level, using stable month keys. This is the base view for all recurring revenue analysis.

| column                   | type    | description                                                                 |
|--------------------------|---------|-----------------------------------------------------------------------------|
| month_start_date         | date    | First calendar day of the month                                             |
| month_end_date           | date    | Last calendar day of the month                                              |
| account_id               | string  | Unique account identifier (FK to `dim_account`)                             |
| plan_id                  | string  | Plan active at the end of the month (FK to `dim_plan`)                      |
| monthly_recurring_revenue| float64 | Normalized monthly recurring revenue amount for the account and plan in USD |

**Description**  
This view provides a consistent snapshot of recurring revenue at each true month end. It joins subscription activity against a generated calendar, applies the active rule (inclusive start, exclusive end), and normalizes revenue into a single field. It is the foundation for ARR, NRR, and movement calculations.

**Definition**  
Constructs a month calendar from `northstar_app.dim_calendar_day`. Flags subscriptions active at `month_end_date` and sums their revenue.  

**Use**  
Single source of truth for MRR and ARR level. Always aggregate from this view.

---

### View: `v_mrr_movements`

Breaks down month-over-month MRR change at the account level into new, expansion, contraction, and churn. Explains *why* revenue shifted.

| column                   | type    | description                                                                 |
|--------------------------|---------|-----------------------------------------------------------------------------|
| month_start_date         | date    | First calendar day of the current month                                     |
| account_id               | string  | Unique account identifier (FK to `dim_account`)                             |
| previous_monthly_revenue | float64 | MRR at the prior month end (zero if the account was not active)             |
| current_monthly_revenue  | float64 | MRR at the current month end (zero if the account is no longer active)      |
| new_revenue              | float64 | MRR gained from accounts starting this month                                |
| expansion_revenue        | float64 | MRR increase from existing accounts whose spend grew                        |
| contraction_revenue      | float64 | MRR decrease from existing accounts whose spend shrank but remained active  |
| churned_revenue          | float64 | MRR lost from accounts that went to zero                                    |

**Description**  
This view compares each account’s MRR across consecutive month ends, classifying the change into one of four movement categories. It allows finance and product teams to understand whether topline growth comes from winning new logos, expanding existing ones, or offsetting risk from contraction and churn.

**Guardrails**  
Reconciliation identity holds by design:  
`ending = starting + new + expansion - contraction - churn`.

---

### View: `v_arr_bridge`

Transforms monthly MRR movements into ARR terms for executive bridge views and board reporting.

| column           | type    | description                                                |
|------------------|---------|------------------------------------------------------------|
| month_start_date | date    | First calendar day of the current month                    |
| new_arr          | float64 | Annualized value of new MRR (`12 * new_revenue`)           |
| expansion_arr    | float64 | Annualized value of expansion revenue                      |
| contraction_arr  | float64 | Annualized value of contraction revenue                    |
| churned_arr      | float64 | Annualized value of churned revenue                        |
| ending_arr       | float64 | Annualized ending recurring revenue for the company        |

**Description**  
ARR Bridge translates month-over-month movements into an annualized format. It gives executives a clear waterfall of how Net New ARR breaks down into new business, expansion, contraction, and churn. This is the standard format for board decks and strategic reviews.

**Use**  
Board style bridges. Keep periods contiguous. Always show absolute Net New ARR next to rates.

---

### View: `v_nrr_monthly`

Measures **Net Revenue Retention (NRR)** across existing accounts only, excluding net new.

| column             | type    | description                                                                 |
|--------------------|---------|-----------------------------------------------------------------------------|
| month_start_date   | date    | First calendar day of the current month                                     |
| starting_mrr       | float64 | Sum of prior month MRR for accounts that were already active                |
| expansion_revenue  | float64 | MRR growth from these same accounts                                         |
| contraction_revenue| float64 | MRR shrinkage from these same accounts                                      |
| churned_revenue    | float64 | MRR lost from these same accounts that went to zero                         |
| nrr                | float64 | Retention ratio = `(starting - contraction - churn + expansion) / starting` |

**Description**  
This view isolates retention by focusing only on accounts that existed at the start of the period. It highlights the health of the install base, showing how much revenue was retained, expanded, or lost. Net new logos are excluded by definition, making it a pure retention metric.

**Notes**  
Excludes net new from the denominator by definition. In this synthetic set, expansion may be small until you introduce adjustments.

---

### View: `v_activation_7d`

Tracks how quickly users activate after signup, at cohort month level.

| column            | type      | description                                                                 |
|-------------------|-----------|-----------------------------------------------------------------------------|
| signup_month      | timestamp | UTC timestamp truncated to month, representing first signup event            |
| signups           | int64     | Number of users who signed up in that month                                 |
| activated_7d      | int64     | Users from that cohort who completed a core action within 7 days             |
| activation_rate_7d| float64   | Activation ratio (`activated_7d / signups`)                                 |

**Description**  
This view measures the effectiveness of onboarding. By checking whether new users complete meaningful actions (like project creation or file upload) within the first week, it provides a leading indicator of product stickiness and long-term retention.

**Signals**  
Sensitive to event sparsity. The event generator guarantees enough signups to keep this stable.

---

### View: `v_pql_accounts`

Flags accounts reaching **Product Qualified Lead (PQL)** status by month.

| column     | type      | description                                              |
|------------|-----------|----------------------------------------------------------|
| account_id | string    | Unique account identifier (FK to `dim_account`)          |
| pql_month  | timestamp | Month when the PQL condition was first satisfied (UTC)   |

**Description**  
This view identifies accounts that meet the PQL definition — either showing explicit buy signals (subscribe clicks) or implicit product engagement (multiple job runs or API calls) within 28 days of signup. It connects product usage to sales readiness, helping align product-led growth with pipeline.

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
