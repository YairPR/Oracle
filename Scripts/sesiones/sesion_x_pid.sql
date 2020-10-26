-- Encuentra la sesion por el PID del sistema operativo
-- despues puede ejecutar @sid
set line 100
SELECT a.sid,a.module,a.OSUSER FROM v$session a,V$process b
WHERE a.paddr = b.addr AND b.spid=&find_pid;


       SID MODULE			OSUSER
---------- ---------------------------- ------------------------------
       418 JDBC Thin Client		srv_oraoem

1 row selected.
