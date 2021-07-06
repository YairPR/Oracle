set lines 160 pages 20000
col sid_serial for a14

col os_db_user for a20
col last_Execution for a8
col module for a32
col kill_pid for a16
col query for a30
col machine for a20
col logon_time for a17
col program for a37
col event for a16
col last_call for 9999

select s.sid || ',' || s.serial# sid_serial, s.osuser || ' '|| s.username os_db_user, s.module, s.status, 'kill -9 '||p.spid
from v$session s, v$process p
where s.paddr = p.addr
and s.sid in (select sid
from gv$access
where object = '&w_obj')
order by 5,4
;

---- USUARIOS

select DISTINCT s.username 
from v$session s, v$process p
where s.paddr = p.addr
and s.sid in (select sid
from gv$access
where object = '&w_obj')
;

select 'alter system kill session '''||s.sid||','||s.serial#||',@'||inst_id||''' immediate;' 
from v$session s, v$process p
where s.paddr = p.addr
and s.sid in (select sid
from gv$access
where object = '&w_obj')
;

set pagesize 0
set line 1000
spool kill.sql
select 'alter system kill session '''||a.sid||','||a.serial#||',@'||b.inst_id||''' immediate;'
from gv$session a, gv$access b
where a.sid=b.sid 
and b.object = '&w_obj';
spool off
