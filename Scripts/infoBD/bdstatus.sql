set line 1000
set linesize 200
col host_name for a15
col open_mode for a20
col STATUS for a10
col OPEN_MODE for a10
col INSTANCE_NAME for a15
col INSTANCE_ROLE for a20
col CREATE_DATE for a25
col STARTUP for a25
colDATABASE_STATUS for a15
select HOST_NAME,INSTANCE_NAME,INSTANCE_ROLE,VERSION,ACTIVE_STATE,STATUS,ARCHIVER,DATABASE_STATUS,OPEN_MODE,LOG_MODE,
TO_CHAR(CREATED,'DD-MM-YYYY HH24:mi') CREATE_DATE,TO_CHAR(STARTUP_TIME,'DD-MM-YYYY HH24:mi') STARTUP 
from v$instance, v$database;  


HOST_NAME       INSTANCE_NAME   INSTANCE_ROLE        VERSION           ACTIVE_ST STATUS     ARCHIVE DATABASE_STATUS   OPEN_MODE  LOG_MODE     CREATE_DATE               STARTUP
--------------- --------------- -------------------- ----------------- --------- ---------- ------- ----------------- ---------- ------------ ------------------------- -------------------------
siaprd          prdsia01        PRIMARY_INSTANCE     9.2.0.7.0         NORMAL    OPEN       STARTED ACTIVE            READ WRITE ARCHIVELOG   17-04-2010 18:16          07-03-2020 01:13






select b.name, b.open_mode, a.status , a.STARTUP_TIME from v$instance a, v$database b where a.INSTANCE_NAME=b.name;

NAME      OPEN_MODE            STATUS       STARTUP_T
--------- -------------------- ------------ ---------
P2KPROD   READ WRITE           OPEN         05-DEC-19
