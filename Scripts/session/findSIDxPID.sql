-- BUsca el SID por el PID

SELECT a.sid,a.module,a.OSUSER FROM v$session a,V$process b
WHERE a.paddr = b.addr AND b.spid=&find_pid
/
