set pagesize 0
set linesize 30000
set long 500000
set longchunksize 500000
set trimspool on
set feed off
SELECT 'select dbms_metadata.get_ddl("'|| object_type || "',
"'||object_name||"',"&&schema")||chr(10)||"/" FROM dual;'
from dba_objects where owner = UPPER('&&schema')
and object_type = 'PACKAGE'
AND OBJECT_NAME = '&obj_name'
/

 select dbms_metadata.get_ddl('PACKAGE', 'PKG_BRKEDI', 'BRKEDI') from dual
