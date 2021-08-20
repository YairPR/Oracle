set heading off
set colsep ,
set lines 250 pages 30000
col db              for a9
col database_role   for a12
col instance_name   for a10
col host_name       for a25
col os_id           for 999
col feature         for a35
col version         for a11
col nusages         for 9999
col feature_info    for a60
alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss';
select b.name db, b.DATABASE_ROLE, c.instance_name, c.host_name, null os_id,
       'Database' feature, c.version, 1 nusages, 'TRUE' currently_used, b.created first_usage_date, null last_usage_date, null last_sample_date, null feature_info
from v$database b, v$instance c
union all
select b.name db, b.DATABASE_ROLE, c.instance_name, c.host_name, null os_id,
       a.parameter feature, c.version, 1 nusages, 'TRUE' currently_used, null first_usage_date, null last_usage_date, null last_sample_date,
	   null feature_info
from v$option a , v$database b, v$instance c
where a.VALUE = 'TRUE'
---order by 1
;
set colsep " "
set heading on
