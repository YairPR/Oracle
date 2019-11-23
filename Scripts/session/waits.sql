-- muestra las sesiones q esperan un bloqueo
set lines 500
select * from dba_waiters where HOLDING_SESSION not in (select WAITING_SESSION from dba_waiters);
