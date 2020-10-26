-- Muestra sesiones activas, 
/*
OS_DB_USER           SID_SERIAL     LAST_EXE MODULE                           QUERY                          MACHINE              LOGON_TIME        PROGRAM                                 LAST_CALL KILL_PID
-------------------- -------------- -------- -------------------------------- ------------------------------ -------------------- ----------------- ------------------------------------- ----------- ----------------
ORACLE SYS           2221,1         06:41:10                                  @s 00 0                        rsdcpdbprod01        20-07-05 06:41:11 oracle@rsdcpdbprod01 (O0-                  146,12 kill -9 66257660
*/

set linesize 2000 pagesize 20000 feedback on
set linesize 2000 pagesize 20000 feedback on
col os_db_user for a20
col sid_serial for a14
col last_Execution for a8
col module for a32
col kill_pid for a16
col query for a30
col machine for a20
col logon_time for a17
col program for a37
col event for a16
col last_call for 9999
SELECT /*+ rule*/ substr(UPPER(s.OsUser) || ' ' || s.UserName, 1, 20) os_db_user,
       s.sid || ',' || s.serial# sid_serial,
       to_char(sysdate-(s.last_call_et/(24*3600)), 'hh24:mi:ss') last_Execution,
       substr(s.module, 1, 32) module,
       '@s '|| s.sql_address || ' '|| s.sql_hash_value QUERY,
       substr(s.machine, 1, 20) machine,
       to_char(LOGON_TIME, 'YY-MM-DD HH24:MI:SS') logon_time,
       substr(s.Program, 1, 24) || '-' || substr(s.action, 1, 12) program,
       LAST_CALL_ET/60 last_call,
       'kill -9 '|| p.spid kill_pid
FROM v$Session s , v$process p
WHERE s.UserName Is Not Null AND  s.Status='ACTIVE' AND  p.addr=s.paddr
order by logon_time
;
