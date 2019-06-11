set line 1000
spool synonym.txt
select 'CREATE OR REPLACE SYNONYM ' || 'PRD_CLEVOL_MOBILE_BATCH' || '.' || table_name || ' FOR ' || OWNER || '.' || table_name || ';'
from dba_tab_privs
where grantee in 
  (select granted_role from dba_role_privs
   where grantee='PRD_CLEVOL_MOBILE_BATCH')
   and owner = 'ORBRWRC';
 spool off
