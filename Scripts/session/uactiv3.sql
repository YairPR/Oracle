------------------------------------------------------------------------------------ 
-- Información de la sesiones activa o inactivas, muestra el comando kill -9, sid, serial ,hash, ADRRES
-- se puede usar en conjunto con el query textq.sql (hassh, address)
-- ingresar usuario, se puede comentar para ver todas las activas, por sid, etc

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

prompt sesiones activas

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
--and sid=622
--and sid in (   1855 ,
and status='ACTIVE'
--and a.spid = 21037228
and b.username <> ' '
--and b.username IN ( '&Usuario')
--and b.module like ( '%ZSDP0098%')
order by last_call;  

RESULT
------
PID	   SID	      SER#	 MODULE 			USERNAME	     OS_USER		  MACHINE		LAST_CALL STATUS   LOGON_TIME		QUERY			       KILL
---------- ---------- ---------- ------------------------------ -------------------- -------------------- -------------------- ---------- -------- -------------------- ------------------------------ --------------------
50654	   940	      52763	 sqlplus@rsdpedbadm03.rimac.com SYS		     oracle		  rsdpedbadm03.rimac.c	      .00 ACTIVE   22/11/2019 21:14:45	0000000419B23BC8 1158942608    kill -9 50654
													  om.pe

135450	   962	      25192	 JDBC Thin Client		DS_ASESOR_PD	     root		  rsdcapjboss01.rimac.	      .10 ACTIVE   22/11/2019 21:34:00	000000041ABF6E00 2907578947    kill -9 135450
													  com.pe

288017	   1305       49355	 phantom@rsdcpds01 (TNS V1-V3)	DT_CTE_SAS	     dsadm		  rsdcpds01		      .23 ACTIVE   22/11/2019 06:00:10	00000000C7BE7F00 714078244     kill -9 288017
352932	   1378       5 	 JDBC Thin Client		DBSNMP		     srv_oraoem 	  rsdpedbadm03.rimac.c	      .23 ACTIVE   06/11/2019 12:50:48	000000041C6CD228 2933305500    kill -9 352932
