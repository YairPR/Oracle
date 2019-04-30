/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2017
*@Descripcion:             Genera la lista de usuarios ACTIVOS en la base de datos y muestra su actividad
*@Versión                  v1.0
*******************************************************************************************************************/

set linesize 1000
set pagesize 10000
set arraysize 10
set maxdata 10000

column su format a20 heading 'Oracle|User ID' justify left
column oux format a16 heading 'System|User ID' justify left
column lw format a4 heading 'Is|Lock' justify left
column sm format a17 heading 'Machine' justify left
column stat format a8 heading 'Session|Status' justify left
column sid format a10 heading 'Oracle|Session|ID' justify right
column spid format a6 heading 'UNIX|Proces|ID' justify right
column lt format a16 heading 'Time|Session' justify right
column rg format a12 heading 'Resource|Group' justify right
column sql_id format a13 heading 'SQLID' justify left
column event format a34 heading 'Event Waiting' justify left
column seq# format 99999
column "Segs." format 999999

  select lpad(p.spid,6) spid, substr(s.sid||','||s.serial#,1,10) sid ,
       decode(s.LOCKWAIT,null,' ','Si') lw,s.username su,
       rpad(s.osuser,16)  oux,
       SUBSTR(TO_CHAR (s.logon_time, 'YYYY/MM/DD HH24:MI'),1,18) lt,
       rpad(s.machine,17) sm, s.sql_id, rpad(s.event,34) event, w.seq#, w.seconds_in_wait "Segs."
  from v$process p,
       v$session s,
       v$session_wait w
where  p.addr=s.paddr
and s.sid=w.sid
and s.status like 'ACTI%'
and    s.username is not null 
order by 6 asc
/
