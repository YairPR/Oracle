col WAITING_SESSION for 999999 heading 'SID_Wait'
col HOLDING_SESSION for 999999 heading 'SID Hold'
col objeto format a40
col kill_pid for a16
col last_query for a30
col machine for a20
col last_call for 99999
col program for a20 heading 'Program/Module'
col xusername for a32 heading 'DB_User - OS_User'
select a.HOLDING_SESSION, b.status, (b.username || ' - ' || b.osuser) xusername,
       a.WAITING_SESSION, 
       (select owner || '.' || obj.object_name from dba_objects obj where obj.OBJECT_ID = nvl(b.ROW_WAIT_OBJ#, 0)) objeto,
       '@s '|| b.sql_address || ' '|| b.sql_hash_value last_QUERY,
       substr(b.machine, 1, 20) machine, substr(nvl(b.program, b.module), 1, 20) program, b.status,
       LAST_CALL_ET/60 last_call
from dba_waiters a, v$session b
where a.MODE_HELD = 'Exclusive'
  and a.HOLDING_SESSION = b.sid (+)
;
