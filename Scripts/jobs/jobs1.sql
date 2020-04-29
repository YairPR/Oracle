set lines 200
col what for a70
alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss';
select a.job, a.what, a.this_date, a.TOTAL_TIME, b.sid || ',' || c.serial# sid_serial, c.status, '@s '|| c.sql_address || ' '|| c.sql_hash_value QUERY
from dba_jobs a, dba_jobs_running b, v$session c
where a.log_user = '&w_usr'
  and a.job = b.job (+)
  and b.sid = c.sid (+)
order by this_date
;
