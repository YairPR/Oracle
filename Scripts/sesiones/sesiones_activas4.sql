-- Script muestra sesiones activas 
-- Parametro a ingresa USERNAME
-- Muestra lo siguiente:
/*
OS_DB_USER           SID_SERIAL     LAST_EXE MODULE                         QUERY                          MACHINE              LOGON_TIME        PROGRAM                               LAST_CALL STATUS   KILL_PID
-------------------- -------------- -------- ------------------------------ ------------------------------ -------------------- ----------------- ------------------------------------- --------- -------- ----------------
OPERADORSB JALARCONT 1835,7101      20:44:10 NumRelIng 17427447             @s 07000116FC8036F8 96492195   RIMAC\RSVDIW8OP01    20-11-01 20:25:27 -Cantidad 1                                  71 INACTIVE kill -9 19202658
*/

set linesize 2000 pagesize 20000 feedback on
set linesize 2000 pagesize 20000 feedback on
col os_db_user for a20
col sid_serial for a14
col last_Execution for a8
col module for a30
col kill_pid for a16
col query for a30
col machine for a20
col logon_time for a17
col program for a37
col event for a16
col last_call for 9999

undefine w_user
SELECT /*+ rule*/ substr(UPPER(s.OsUser) || ' ' || s.UserName, 1, 20) os_db_user,
       s.sid || ',' || s.serial# sid_serial,
       to_char(sysdate-(s.last_call_et/(24*3600)), 'hh24:mi:ss') last_Execution,
       substr(s.module, 1, 30) module,
       '@s '|| s.sql_address || ' '|| s.sql_hash_value QUERY,
       substr(s.machine, 1, 20) machine,
       to_char(LOGON_TIME, 'YY-MM-DD HH24:MI:SS') logon_time,
       substr(s.Program, 1, 24) || '-' || substr(s.action, 1, 12) program,
       LAST_CALL_ET/60 last_call, s.status,
       'kill -9 '|| p.spid kill_pid
FROM v$Session s , v$process p
WHERE s.UserName = '&w_user'  AND  p.addr=s.paddr
order by logon_time
;

