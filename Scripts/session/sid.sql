set lines 300 pages 20000
set verify off
col inst_id for 99
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
col last_call for 99999
undefine w_sid
SELECT UPPER(s.OsUser) || ' ' || s.UserName os_db_user,
       s.sid || ',' || s.serial# sid_serial,
       to_char(sysdate-(s.last_call_et/(24*3600)), 'hh24:mi:ss') last_Execution,
       substr(s.module, 1, 32) module,
       s.status,
       'kill -9 '|| p.spid kill_pid, 
       '@s '|| s.sql_address || ' '|| s.sql_hash_value QUERY,
       s.machine , 
       to_char(LOGON_TIME, 'YY-MM-DD HH24:MI:SS') logon_time,
       substr(s.Program, 1, 24) || '-' || substr(s.action, 1, 12) program,
       LAST_CALL_ET/60 last_call
FROM v$Session s , v$process p 
WHERE p.addr = s.paddr
  and s.sid = &&w_sid
;
undef w_sid
set verify on
