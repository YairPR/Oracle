set linesize 200
col host_name for a15
col open_mode for a20
col STATUS for a10
col OPEN_MODE for a10
select HOST_NAME,INSTANCE_NAME,INSTANCE_ROLE,VERSION,ACTIVE_STATE,STATUS,ARCHIVER,DATABASE_STATUS,OPEN_MODE,LOG_MODE,
TO_CHAR(CREATED,'DD-MM-YYYY HH24:mi') CREATE_DATE,TO_CHAR(STARTUP_TIME,'DD-MM-YYYY HH24:mi') STARTUP 
from v$instance, v$database;  





select b.name, b.open_mode, a.status , a.STARTUP_TIME from v$instance a, v$database b where a.INSTANCE_NAME=b.name;

NAME      OPEN_MODE            STATUS       STARTUP_T
--------- -------------------- ------------ ---------
P2KPROD   READ WRITE           OPEN         05-DEC-19
