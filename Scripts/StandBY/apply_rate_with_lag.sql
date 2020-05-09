rem Reports standby apply rate with lag
rem
select TIMESTAMP,completion_time "ArchTime",
SEQUENCE#,round((blocks*block_size)/(1024*1024),1) "SizeM",
round((TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP) OVER (order by TIMESTAMP))*24*60*60,1) "Diff(sec)",
round((blocks*block_size)/1024/ decode(((TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP)
OVER (order by TIMESTAMP))*24*60*60),0,1,
(TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP) OVER (order by TIMESTAMP))*24*60*60),1) "KB/sec",
round((blocks*block_size)/(1024*1024)/ decode(((TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP)
OVER (order by TIMESTAMP))*24*60*60),0,1,
(TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP) OVER (order by TIMESTAMP))*24*60*60),3) "MB/sec",
round(((lead(TIMESTAMP,1,TIMESTAMP) over (order by TIMESTAMP))-completion_time)*24*60*60,1) "Lag(sec)"
from v$archived_log a, v$dataguard_status dgs
where a.name = replace(dgs.MESSAGE,'Media Recovery Log ','')
and dgs.FACILITY = 'Log Apply Services'
order by TIMESTAMP desc;
