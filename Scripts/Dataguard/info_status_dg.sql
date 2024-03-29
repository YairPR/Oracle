ESTADO DE DATAGUARD:

@last
 select 'Last applied  : ' Logs, to_char(next_time,'DD-MON-YY:HH24:MI:SS') Time
    from v$archived_log
    where sequence# = (select max(sequence#) from v$archived_log where applied='YES')
    union
    select 'Last received : ' Logs, to_char(next_time,'DD-MON-YY:HH24:MI:SS') Time
    from v$archived_log
   where sequence# = (select max(sequence#) from v$archived_log);
 
 
LOGS             TIME
---------------- ---------------------------------------------------------------------------
Last applied  :  25-APR-23:08:55:01
Last received :  25-APR-23:08:55:01



 @dg_stats
 set line 300
 column value format a50
 select
    NAME Name,
    VALUE Value,
    UNIT Unit
    from v$dataguard_stats
    union
    select null,null,' ' from dual
    union
    select null,null,'Time Computed: '||MIN(TIME_COMPUTED)
   from v$dataguard_stats;
  
  NAME                             VALUE                                              UNIT
-------------------------------- -------------------------------------------------- ---------------------------------------------

                                                                                    Time Computed:


   @last_redo
   select to_char(max(last_time),'DD-MON-YYYY HH24:MI:SS') "Redo onsite"
     from v$standby_log

Redo onsite
---------------------------------------------------------------------------

##########################################################################################################################################################
ROL BD:

Script 1:
set line 1000
set heading on
set feedback on
col db_unique_name format a15
col flashb_on format a10
prompt ESTADO BASE DE DATOS STAND_BY
select DB_UNIQUE_NAME,DATABASE_ROLE DB_ROLE,FORCE_LOGGING F_LOG,FLASHBACK_ON FLASHB_ON,LOG_MODE,OPEN_MODE,
       GUARD_STATUS GUARD,PROTECTION_MODE PROT_MODE
from v$database;

Script 2:

set echo off 
set feedback off 
set lines 132
set pagesize 500
set numformat 999999999999999
set trim on 
set trims on 
-- Get the current Date
set feedback on 
select systimestamp from dual;
-- Standby Site Details
set heading off
set feedback off
select '*******************************************' from dual;
select '            Standby Site Details ' from dual;
select '*******************************************' from dual;
set heading on
set feedback on
col db_unique_name format a15
col flashb_on format a10
select DB_UNIQUE_NAME,DATABASE_ROLE DB_ROLE,FORCE_LOGGING F_LOG,FLASHBACK_ON FLASHB_ON,LOG_MODE,OPEN_MODE,
       GUARD_STATUS GUARD,PROTECTION_MODE PROT_MODE
from v$database;

prompt ESTADO PROCESOS DG
select PROCESS,STATUS,CLIENT_PROCESS,CLIENT_PID,THREAD#,SEQUENCE#,BLOCK#,ACTIVE_AGENTS,KNOWN_AGENTS
from v$managed_standby  order by CLIENT_PROCESS,THREAD#,SEQUENCE#;

prompt ULTIMA SECUENCIA APLICADA
SELECT ARCH.THREAD# "Thread", ARCH.SEQUENCE# "Last Sequence Received", APPL.SEQUENCE# "Last Sequence Applied", (ARCH.SEQUENCE# - APPL.SEQUENCE#) "Difference"
FROM (SELECT THREAD# ,SEQUENCE# FROM V$ARCHIVED_LOG WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$ARCHIVED_LOG GROUP BY THREAD#)) ARCH,
(SELECT THREAD# ,SEQUENCE# FROM V$LOG_HISTORY WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$LOG_HISTORY GROUP BY THREAD#)) APPL
WHERE ARCH.THREAD# = APPL.THREAD#;


-- Current SCN - this value on the primary and standby sites where real time apply is in place should be nearly the same
