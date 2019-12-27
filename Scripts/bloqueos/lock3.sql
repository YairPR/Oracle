col WAITING_SESSION for 999999 heading 'SID_Wait'
col HOLDING_SESSION for 999999 heading 'SID Hold'
col objeto format a40
col kill_pid for a16
col last_query for a30
col machine for a20
col last_call for 99999
col program for a20 heading 'Program/Module'
col xusername for a32 heading 'DB_User - OS_User'
col kill_sesion for a40
select a.HOLDING_SESSION, b.status, (b.username || ' - ' || b.osuser) xusername,
       a.WAITING_SESSION, c.status status_w,
       '@s '|| b.sql_address || ' '|| b.sql_hash_value last_QUERY,
       substr(b.machine, 1, 20) machine, substr(nvl(b.program, b.module), 1, 20) program,
       b.LAST_CALL_ET/60 last_call,
       'alter system kill session ''' || b.sid || ',' || b.serial# || ''';' kill_sesion
from dba_waiters a, v$session b, v$session c
where a.MODE_HELD = 'Exclusive'
  and a.HOLDING_SESSION = b.sid (+)
  and a.WAITING_SESSION = c.sid (+)
;
