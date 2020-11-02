set lines 300 pages 20000
set verify off
col inst_id for 99
col os_db_user for a20
col sid_serial for a14
col last_Execution for a8
col module for a20
col kill_pid for a14
col query for a30
col machine for a20
col logon_time for a17
col program for a37
col event for a16
col last_call for 99999
SELECT /*+ rule*/ UPPER(s.OsUser) || ' ' || s.UserName os_db_user,
       s.sid || ',' || s.serial# sid_serial,
       to_char(sysdate-(s.last_call_et/(24*3600)), 'hh24:mi:ss') last_Execution,
       substr(s.module, 1, 20) module,
       'kill -9 '|| p.spid kill_pid, 
       '@s '|| s.sql_address || ' '|| s.sql_hash_value QUERY,
       s.machine , 
       to_char(LOGON_TIME, 'YY-MM-DD HH24:MI:SS') logon_time,
       substr(s.Program, 1, 24) || '-' || substr(s.action, 1, 12) program,
       substr(s.EVENT, 1, 16) event,
       LAST_CALL_ET/60 last_call
FROM v$Session s , v$process p 
WHERE p.addr = s.paddr
  and s.sid = &&w_sid
;
select b.sql_address, b.sql_hash_value, b.sql_id, a.sql_text 
from v$sqltext a, v$session b 
where a.address = b.sql_address
  and a.hash_value = b.sql_hash_value
  and b.sid = &&w_sid
order by piece
;
select stat_id, stat_name, value from v$sess_time_model
where sid = &&w_sid
  and value is not null
  and value != '0'
order by value desc
;
SELECT WAIT_CLASS_ID, WAIT_CLASS#, WAIT_CLASS, TOTAL_WAITS TIME_WAITED
FROM   v$session_wait_class
WHERE  sid = &&w_sid
order by TOTAL_WAITS
;
undef w_sid
set verify on

