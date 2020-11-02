set lines 500;
set pages 500;
col pid format a10
col sid format a10
col ser# format a10
col module format a30
col username format a20
col machine format a20
col QUERY format a30
col last_call format 999999.99
col PROGRAM format a20
col KILL format a20
col OS_USER format a20
col LOGON_TIME format a20

select       
       to_char(a.spid) pid,
       to_char(b.sid) sid,
       to_char(b.serial#) ser#,       
       substr(b.module,1,30) module,
       b.username username,
--       b.server,
       b.osuser os_user,
       substr(b.machine,1,30) machine,
--       substr(b.program,1,30) program,
        LAST_CALL_ET/60 last_call,
        b.status,
        to_char(b.Logon_Time,'dd/mm/yyyy hh24:mi:ss') Logon_Time,
        b.sql_address||' '|| b.sql_hash_value QUERY,
        'kill -9 '||a.spid kill
from v$session b, v$process a
where b.paddr = a.addr
--and b.serial# = 41396
--and sid=804
--and sid in (   1855 ,
--and status='INACTIVE'
--and a.spid = 21037228
and b.username <> ' '
and b.username = upper( '&username')
--and b.module like ( '%ZSDP0098%')
order by last_call;
