set lines 200
col what for a70
alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss';
select b.sid, a.what, a.this_date, a.TOTAL_TIME, a.failures
from dba_jobs a, dba_jobs_running b
where a.log_user = '&w_usr'
  and a.job = b.job (+)
order by a.job
;
