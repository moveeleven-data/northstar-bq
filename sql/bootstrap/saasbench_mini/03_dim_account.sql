create table if not exists `northstar-bq.saasbench_mini.dim_account` as
with id_pool as (select generate_array(1, 500) as ids)
select
  format('A%04d', id) as account_id,
  if(rand() < 0.15, 'enterprise', if(rand() < 0.5, 'mid', 'small')) as segment,
  if(rand() < 0.5, 'us', if(rand() < 0.75, 'eu', 'apac')) as region,
  date_add(date_sub(current_date(), interval 600 day), interval cast(rand()*540 as int64) day) as first_seen_date
from id_pool, unnest(ids) as id;