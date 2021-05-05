- Listar procesos 
- Bloqueos
- Top CPU
- Top IO
- Sessions Stats
- SQL_ID
- SGA History
- Snapper


#######################################################################
Long Running SQL (V$SESSION_LONGOPS)
#######################################################################
- Contents:
Active SQL
Find Long Operations
Check Time Remaining Of Export/Import
Monitor Index Creation
Queries currently running for more than 60 seconds
Oracle Locks

La vista V$SESSION_LONGOPS  muestra varios operaciones que estan ejecuntando por mas de 60 segundos

Estas operaciones actualmente incluyen:
Backup and recovery functions
Statistics gathering
Query execution
Import progress
Index Creation etc..

To monitor query execution progress, you must be using the cost-based optimizer and you must:
·         Set the TIMED_STATISTICS or SQL_TRACE parameter to true
·         Gather statistics for your objects with the ANALYZE statement or the DBMS_STATS package

You can add information to this view about application-specific long-running operations by using the DBMS_APPLICATION_INFO.SET_SESSION_LONGOPS procedure.

=================
QUERYS REVISION =
=================

-Active SQL
set lines 200 pages 200
col SQL_TEXT for a77
select S.USERNAME, s.sid, s.osuser, sql_text
from v$sqltext_with_newlines t,V$SESSION s
where t.address =s.sql_address
and t.hash_value = s.sql_hash_value
and s.status = 'ACTIVE'
and s.username <> ' '
----AND USERNAME='&USERNAME'
order by s.sid,t.piece;

Find Long Operations (e.g. full table scans, RMAN, Insert, Import)

select substr(sql_text,instr(sql_text,'INTO "'),30) table_name,
         rows_processed,
         round((sysdate-to_date(first_load_time,'yyyy-mm-dd hh24:mi:ss'))*24*60,1) Minutes,
         trunc(rows_processed/((sysdate-to_date(first_load_time,'yyyy-mm-dd hh24:mi:ss'))*24*60)) Rows_Per_Minute
from   sys.v_$sqlarea
where  sql_text like 'INSERT %INTO "%'
and  command_type = 2
and  open_versions > 0;

OR

set lines 200 pages 200
col username format a20
col message format a70
--col remaining format 9999
select    username||'-'||sid||','||SERIAL# username
,    to_char(start_time, 'hh24:mi:ss dd/mm/yy') started
,    time_remaining remaining_Sce
,    ELAPSED_SECONDS
,    round((sofar/totalwork)* 100,2) "COMPLETE%"
,    message
from    v$session_longops
where    time_remaining <> 0
----and TARGET like '%&USERNAME.%'
order by time_remaining desc;


Check Time Remaining Of Export/Import

SELECT  table_name
    ,rows_processed
    ,Minutes,Rows_Per_Minute
    ,(1/Rows_Per_Minute)*(147515763-rows_processed) Time_Remaining_Min From
    (select substr(sql_text,instr(sql_text,'INTO "'),30) table_name,
     rows_processed,
     round((sysdate-to_date(first_load_time,'yyyy-mm-dd hh24:mi:ss'))*24*60,1) Minutes,
     trunc(rows_processed/((sysdate-to_date(first_load_time,'yyyy-mm-dd hh24:mi:ss'))*24*60)) Rows_Per_Minute
from       sys.v_$sqlarea
where      sql_text like 'INSERT %INTO "%'
and      command_type = 2
and      open_versions > 0);

Monitor Index Creation

col sid format 9999
col start_time format a5 heading "Start|time"
col elapsed format 9999 heading "Mins|past"
col min_remaining format 9999 heading "Mins|left"
col message format a81
select sid
, to_char(start_time,'hh24:mi') start_time
, elapsed_seconds/60 elapsed
, round(time_remaining/60,2) "min_remaining"
, message
from v$session_longops where time_remaining > 0
AND MESSAGE like '%&TABLE_NAME.%';
--AND MESSAGE like '%&USWENAME.TABLE_NAME.%';


Queries currently running for more than 900 seconds (For Procedure & Package)

select s.username,s.sid,s.serial#,s.last_call_et/60 mins_running,q.sql_text from v$session s
join v$sqltext_with_newlines q
on s.sql_address = q.address
 where status='ACTIVE'
and type <>'BACKGROUND'
and last_call_et> 900
order by sid,serial#,q.piece;

Oracle Locks

select
  object_name,
  object_type,
  session_id,
  type,                 -- Type or system/user lock
  lmode,        -- lock mode in which session holds lock
  request,
  block,
  ctime                 -- Time since current mode was granted
from
  v$locked_object, all_objects, v$lock
where
  v$locked_object.object_id = all_objects.object_id AND
  v$lock.id1 = all_objects.object_id AND
  v$lock.sid = v$locked_object.session_id
order by
  session_id, ctime desc, object_name
/
           
