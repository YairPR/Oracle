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
       'kill -9 '|| p.spid kill_pid,
       '@s '|| s.sql_address || ' '|| s.sql_hash_value QUERY,
       substr(s.machine, 1, 20) machine,
       to_char(LOGON_TIME, 'YY-MM-DD HH24:MI:SS') logon_time,
       substr(s.Program, 1, 24) || '-' || substr(s.action, 1, 12) program,
       LAST_CALL_ET/60 last_call, s.status
FROM v$Session s , v$process p
WHERE s.osuser like '&&w_user'  AND  p.addr=s.paddr
---    and  s.status = 'ACTIVE'
order by logon_time
;

