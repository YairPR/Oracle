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
