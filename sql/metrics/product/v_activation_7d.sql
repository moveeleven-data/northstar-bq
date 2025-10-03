create or replace view `northstar-bq.northstar_metrics.v_activation_7d` as

/*
   v_activation_7d.sql
   Purpose: Measure activation within 7 days of signup and report cohort-level activation by signup month.

   Definitions:
     - Signup date: first signup event date if present, else dim_account.first_seen_date.
     - Activation event: any of ('project_create', 'file_upload', 'api_call', 'job_run').
     - Activation window: [signup_date, signup_date + 7 days), inclusive of signup_date, exclusive of day 7.
*/

with

-- Resolve a signup_date for every account.
account_signup as (
  select
      account_id
    , coalesce(signup_date, first_seen_date) as signup_date
  from `northstar-bq.northstar_app.dim_account` as accounts
  left join (
    select
        account_id
      , cast(min(event_timestamp) as date) as signup_date
    from `northstar-bq.northstar_app.fact_product_events`
    where event_name = 'signup'
    group by account_id
  ) as signup_events
        using (account_id)
)

-- All candidate activation events.
, activation_events as (
  select
      events.account_id
    , cast(events.event_timestamp as date) as activation_event_date
  from `northstar-bq.northstar_app.fact_product_events` as events
  where
       events.event_name in (
            'project_create'
          , 'file_upload'
          , 'api_call'
          , 'job_run'
       )
)

-- Join accounts to activation events that occurred in the 7-day window after signup.
, activation_within_7d as (
  select
      signup.account_id
    , signup.signup_date
    , events.activation_event_date
  from account_signup as signup
  left join activation_events as events
      on events.account_id = signup.account_id
     and events.activation_event_date >= signup.signup_date
     and events.activation_event_date < date_add(signup.signup_date, interval 7 day)
)

-- Collapse to one row per account
-- As long as user has any associated activation_event_date, they are active.
, account_activation as (
  select
      account_id
    , signup_date
    , case
          when min(activation_event_date) is not null then true
          else false
      end as activated_7d_flag
  from activation_within_7d
  group by
      account_id
    , signup_date
)

, cohort_metrics as (
  select
      timestamp_trunc(timestamp(signup_date), month) as signup_month
    , count(*) as signups
    , countif(activated_7d_flag) as activated_7d
    , round(
          safe_divide(
             countif(activated_7d_flag)
           , COUNT(*)
          )
        , 2
      ) as activation_rate_7d
  from account_activation
  group by signup_month
)

select
    signup_month
  , signups
  , activated_7d
  , activation_rate_7d
from cohort_metrics;
