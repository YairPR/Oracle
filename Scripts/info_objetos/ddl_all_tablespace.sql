set heading off;
set echo off;
Set pages 999;
set long 90000;
spool ddl_list.sql
select dbms_metadata.get_ddl('TABLESPACE',tb.tablespace_name) from dba_tablespaces tb;
spool off
