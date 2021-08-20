set heading off
set colsep ,
set lines 250 pages 30000
col db              for a9
col database_role   for a16
col instance_name   for a10
col host_name       for a25
col os_id           for 999
col feature         for a32
col version         for a11
col nusages         for 9999
col feature_info    for a60
alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss';
select b.name db, b.DATABASE_ROLE, c.instance_name, c.host_name, b.platform_id os_id,
       'Database' feature, c.version, 1 nusages, 'TRUE' currently_used, b.created first_usage_date, sysdate last_usage_date, null last_sample_date, null feature_info
from v$database b, v$instance c
union all
select b.name db, b.DATABASE_ROLE, c.instance_name, c.host_name, b.platform_id os_id,
       a.name feature, a.version, a.detected_usages nusages, a.currently_used, a.first_usage_date, a.last_usage_date, a.last_sample_date,
	   dbms_lob.substr(a.feature_info, 60, 1) feature_info
from DBA_FEATURE_USAGE_STATISTICS a , v$database b, v$instance c
where a.detected_usages > 0
  and (a.name like '%ADDM%'
     or a.name like '%Automatic Database Diagnostic Monitor%'
     or a.name like '%Automatic Workload Repository%'
     or a.name like '%AWR%'
     or a.name like '%Baseline%'
     or (a.name like '%Compression%' and a.name not like '%HeapCompression%')
     or a.name like '%Data Guard%'
     or a.name like '%Data Mining%'
     or a.name like '%Database Replay%'
     or a.name like '%EM%'
     or a.name like '%Encrypt%'
     or a.name like '%Exadata%'
     or a.name like '%Flashback Data Archive%'
     or a.name like '%Label Security%'
     or a.name like '%OLAP%'
     or a.name like '%Pack%'
     or a.name like '%Partitioning%'
     or a.name like '%Real Application Clusters%'
     or a.name like '%SecureFile%'
     or a.name like '%Spatial%'
     or a.name like '%SQL Monitoring%'
     or a.name like '%SQL Performance%'
     or a.name like '%SQL Profile%'
     or (a.name like '%SQL Tuning%' and a.name not like 'Automatic SQL Tuning Advisor')
     or a.name like '%SQL Access Advisor%'
     or a.name like '%Vault%')
---order by 1
;
set colsep " "
set heading on
