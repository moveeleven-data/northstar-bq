create table if not exists `northstar-bq.saasbench_mini.calendar_day` as
select day
from unnest(generate_date_array(date_sub(current_date(), interval 730 day), current_date())) as day;