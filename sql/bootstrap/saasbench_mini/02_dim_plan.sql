create table if not exists `northstar-bq.saasbench_mini.dim_plan` as
select * from unnest([
  struct('free' as plan_id, 'Free' as plan_name, 'seat' as pricing_model, 0.00 as list_price_month,  cast(null as float64) as unit_rate_usd),
  struct('team' as plan_id, 'Team' as plan_name, 'seat' as pricing_model, 20.00 as list_price_month, cast(null as float64) as unit_rate_usd),
  struct('pro'  as plan_id, 'Pro'  as plan_name, 'seat' as pricing_model, 50.00 as list_price_month, cast(null as float64) as unit_rate_usd),
  struct('usage' as plan_id, 'Usage' as plan_name, 'usage' as pricing_model, 0.00 as list_price_month, 0.02 as unit_rate_usd)
]);