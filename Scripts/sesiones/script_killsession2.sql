-- per user
select       
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
/


-- per user INACTIVE
select       
        'kill -9 '||a.spid kill
from v$session b, v$process a
where b.paddr = a.addr
--and b.serial# = 41396
--and sid=804
--and sid in (   1855 ,
and status='INACTIVE'
--and a.spid = 21037228
and b.username <> ' '
and b.username = upper( '&username')
--and b.module like ( '%ZSDP0098%')
/


-- active sessions

select       
        'kill -9 '||a.spid kill
from v$session b, v$process a
where b.paddr = a.addr
--and b.serial# = 41396
--and sid=804
--and sid in (   1855 ,
--and status='INACTIVE'
--and a.spid = 21037228
and b.username <> ' '
and b.status = 'ACTIVE'
and b.username not in ('DBSNMP', 'SYS')
--and b.username = upper( '&username')
--and b.module like ( '%ZSDP0098%')
/


set pagesize 1000
select       
        'kill -9 '||a.spid kill
from v$session b, v$process a
where b.paddr = a.addr
--and b.serial# = 41396
--and sid=804
--and sid in (   1855 ,
--and status='INACTIVE'
--and a.spid = 21037228
and b.username <> ' '
and b.username not in ('DBSNMP', 'SYS', 'MANTENIMINETO', 'DS_AWSPROD')
--and b.module like ( '%ZSDP0098%')
/
