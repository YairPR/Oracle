set lines 200
col sql_cmd for a80
alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss';

select 'alter ' ||
       case
       when object_type = 'SYNONYM' and OWNER = 'PUBLIC'
            then 'public synonym ' || object_name || ' compile;'
       when object_type = 'SYNONYM' and OWNER != 'PUBLIC'
            then 'synonym ' || owner || '.' || object_name || ' compile;'
       when object_type = 'PACKAGE BODY'
            then 'package ' ||  owner || '.' || object_name || ' compile BODY  REUSE SETTINGS;'
       else
            object_type || ' ' || owner || '.' || object_name || ' compile;'
       end sql_cmd,
       LAST_DDL_TIME
from dba_objects
where status = 'INVALID'
---where object_name in ('SP_RE_PROCESO_ONLINE', 'PR_CARGA_INICIAL_SUSALUD')
order by LAST_DDL_TIME;
