--- Informacion de sesiones activas e inactivas
--- forma de reporte y sumatoria de sesiones

set feed off
set pagesize 1000
set linesize 1000
column sid format 9999999
column ID_SO format a9
column usuario format a17
column serial format 9999999
column maquina format a30
column aplicación format a15
column STATUS format a8
column Fecha_Hora format a16
select a.sid SID,
a.serial# serial,
a.lockwait,
 b.spid ID_SO,
     decode(a.type,'BACKGROUND','*Proceso Oracle',decode(a.username,null,'*Proceso Oracle',a.username)) Usuario,
      decode(a.type,'BACKGROUND','*SERVIDOR ',decode(a.machine,null,'*SERVIDOR ',machine)) Maquina,
      substr(a.program,1,15) Aplicacion,
      a.status STATUS,
      to_char(logon_time,'DD MON HH24:MI:SS') Fecha_Hora
from v$session a, v$process b
where (a.paddr=b.addr and type='USER' and status in ('INACTIVE'))
order by a.program;
     -- and (a.username is not null and machine is not null);
set heading off
ttitle off
select lpad(' ',120,'=') from dual;
select lpad(' ',39,' '),'Conexiones Activas   ','==> '||to_char(count(*)-1,'9999')
from v$session where type='USER' and status in ('ACTIVE')
union
select lpad(' ',39,' '),'Conexiones Inactivas','==> '||to_char(count(*)+1,'9999')
from v$session where type='USER' and status in ('INACTIVE')
union
select lpad(' ',39,' '),'Conexiones Killed   ','==> '||to_char(count(*),'9999')
from v$session where type='USER' and status in ('KILLED')
union
select lpad(' ',39,' '),'Total  Conexiones   ','==> '||to_char(count(*),'9999')
from v$session where type='USER' and status in ('INACTIVE','ACTIVE','KILLED');
set heading on
ttitle on
                                                     
/*
SID   SERIAL LOCKWAIT	   ID_SO     USUARIO	       MAQUINA			      APLICACION      STATUS   FECHA_HORA
-------- -------- ---------------- --------- ----------------- ------------------------------ --------------- -------- ----------------
 1027    10572		         16420     XT1771	       01-040726				                   INACTIVE   06 NOV 11:11:35
 111      147		          16467     XT1771	       01-040726				                   INACTIVE   06 NOV 11:11:37
 1347    57359		         23376     XT1771	       01-040726				                   INACTIVE   06 NOV 11:13:10
SQL> SQL> SQL> SQL>
=======================================================================================================================
SQL>   2    3    4    5    6    7    8    9   10   11  
					Conexiones Activas    ==>     9
					Conexiones Inactivas  ==>   389
					Conexiones Killed     ==>     0
					Total  Conexiones     ==>   399

*/
