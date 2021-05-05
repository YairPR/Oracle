spool myxlsfile.xls
SET MARKUP HTML ON ENTMAP ON PREFORMAT OFF ;
select 	to_char(end_time,'hh24:mi:ss') as sample_time,
		value
from 	v$sysmetric_history
where 	end_time between sysdate - interval '1' hour and sysdate
and 	group_id = 2
and 	metric_name = 'Host CPU Utilization (%)'
order by metric_name, end_time;
spool off
