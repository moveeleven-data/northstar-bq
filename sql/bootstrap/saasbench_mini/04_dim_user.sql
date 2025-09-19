create table if not exists `northstar-bq.saasbench_mini.dim_user` as
with base as (select account_id, first_seen_date from `northstar-bq.saasbench_mini.dim_account`)
select
  format('U%06d', row_number() over()) as user_id,
  account_id,
  if(rand() < 0.6, 'admin', 'member') as role,
  date_add(first_seen_date, interval cast(rand()*400 as int64) day) as created_date
from base
cross join unnest(generate_array(1, cast(2 + rand()*3 as int64)));