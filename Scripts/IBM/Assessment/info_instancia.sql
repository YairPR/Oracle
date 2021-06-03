alter session set nls_date_format='DD-MON-YYYY hh24:mi:ss';
set echo off
set termout on
set heading on
set feedback off
set trimspool on
set linesize 200
set pagesize 5000
set long 5000
set markup html on spool on
col spoolname new_value spoolname 
select 'assesment_'||host_name||'-'||instance_name||'.html'  spoolname from v$instance;
spool '&spoolname'

-----------------------------------------------
prompt 1. Informacion de la Base de Datos e Instancias
-----------------------------------------------

col "Name" format a30
col value format a30
set line 100
set pagesize 200
select 'Database Name' "Name", name "VALUE" from v$database union 
SELECT 'Oracle Version' , version FROM V$INSTANCE union 
select 'Date Created', to_char(Created,'dd-mm-yyyy hh24:mi:ss') from V$database union 
select 'Host Plataform', PLATFORM_NAME from V$database union 
select 'Log Mode', log_mode from V$database union
SELECT 'Flashback Database', flashback_on FROM v$database union
Select 'Dataguad Broker', dataguard_broker FROM v$database union
Select 'Database Role', database_role FROM v$database union
Select 'Guard Status', guard_status FROM v$database union
select UPPER(substr(name,1,1)) ||substr(name,2,30) "Name", value from v$parameter  where name in ('db_block_size','cluster_database','compatible')  union 
select 'Instancias' , a.instance_name||', '||b.instance_name from gv$instance a, gv$instance b where a.inst_id=1 and b.inst_id=2 union 
SELECT 'Host Name' , a.host_name ||', '|| b.host_name   FROM gV$INSTANCE a, gv$instance b where a.inst_id=1 and b.inst_id=2 union
SELECT 'Host Name' , a.host_name  FROM V$INSTANCE a union 
SELECT 'Startup Instance' , to_char(STARTUP_TIME,'dd-mm-yyyy hh24:mi:ss')  FROM V$INSTANCE a union  
SELECT 'Character Set', value$ FROM sys.props$ WHERE name = 'NLS_CHARACTERSET' union 
SELECT 'Default Permanent Tablespace', PROPERTY_VALUE FROM DATABASE_PROPERTIES WHERE PROPERTY_NAME ='DEFAULT_PERMANENT_TABLESPACE' union 
SELECT 'Default Temporary Tablespace', PROPERTY_VALUE FROM DATABASE_PROPERTIES WHERE PROPERTY_NAME = 'DEFAULT_TEMP_TABLESPACE' union 
select 'Tablespaces' , to_char(count(*)) from v$tablespace union 
select 'Users' , to_char(count(*)) from dba_users union 
select UPPER(substr(a.name,1,1)) ||substr(a.name,2,30) "Name", b.instance_name||'-'||value from gv$parameter a,  gv$instance b where a.inst_id=b.inst_id  and a.name= 'undo_tablespace'  union 
select UPPER(substr(a.name,1,1)) ||substr(a.name,2,30) "Name", b.instance_name||'-'||round(value/1024/1024/1024,2)||'GB' from gv$parameter a, gv$instance b where a.inst_id=b.inst_id and a.name= 'memory_target'  union 
select UPPER(substr(a.name,1,1)) ||substr(a.name,2,30) "Name", b.instance_name||'-'||round(value/1024/1024/1024,2)||'GB' from gv$parameter a, gv$instance b where a.inst_id=b.inst_id and a.name= 'sga_max_size'  union 
select UPPER(substr(a.name,1,1)) ||substr(a.name,2,30) "Name", b.instance_name||'-'||round(value/1024/1024/1024,2)||'GB' from gv$parameter a, gv$instance b  where a.inst_id=b.inst_id and a.name= 'sga_target';  

 set pagesize 200
set line 2000
column db_name format a7
column instance_name format a13
column host_name format a12
column open_mode format a11
column name format a7
column platform_name format a30
column status format a7
column db_role format a9
column version format a10
column COMP_NAME format a50
select instance_name , status, database_role db_role, substr(host_name,1,20) host_name, version, to_char(STARTUP_TIME,'dd-mon-yy hh24:mi:ss')
 startup, to_char(sysdate,'dd-mon-yy hh24:mi:ss') TODAY,  PLATFORM_NAME from v$database,gv$instance;

--------------------------------------------------------
prompt Tamaño de base de datos total fisica y datos.
--------------------------------------------------------

col "Database Size" format a20
col "Free space" format a20
col "Used space" format a20
select name,     round((sum(used.bytes) / 1024 / 1024 / 1024),2 ) "Database_SizeGb"
,     round((sum(used.bytes) / 1024 / 1024 / 1024),2 ) - 
     round((free.p / 1024 / 1024 / 1024),2)  "Used_GB"
,     round((free.p / 1024 / 1024 / 1024),2)  "Free_GB"
from   v$database, (select     bytes
     from     v$datafile
     union     all
     select     bytes
     from      v$tempfile
     union      all
     select      bytes
     from      v$log) used
,     (select sum(bytes) as p
     from dba_free_space) free
group by name,free.p;

--------------------------------------------
prompt 3. Ubicacion Files DB
--------------------------------------------
set pagesize 300
set line 150
select 'File Type' as "File Type", 'Location' As "Location", 'Tamaño' as "Size MB" from dual union 
select 'Datafiles', (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))), To_char(trunc(sum(bytes/1024/1024))) 
from dba_data_files group by  (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) union 
select distinct 'Tempfiles', (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) , to_char(trunc(sum(bytes/1024/1024))) 
from dba_temp_files group by SUBSTR(file_name,1,INSTR(file_name,'\',-1,1)) union
select  'Flash Recover Area', name , to_char(trunc(space_used/1024/1024))from v$recovery_file_dest  union 
select distinct 'Redo Logs' , (SUBSTR(a.member,1,INSTR(member,'\',-1,1))), to_char(sum(b.BYTES/1024/1024)) 
from v$logfile a, v$log b where a.group#=b.group# group by SUBSTR(a.member,1,INSTR(member,'\',-1,1)) union 
select  'Controlfiles' ,(SUBSTR(name,1,INSTR(name,'\',-1,1))), to_char(trunc(sum(BLOCK_SIZE*FILE_SIZE_BLKS/1024/1024))) from v$controlfile group by SUBSTR(name,1,INSTR(name,'\',-1,1)) ;


-----------------------------------------------------------
prompt Revision de espacio disponible en los tablespaces.
-----------------------------------------------------------

set line 200
set pagesize 60
col TABLESPACE_NAME for a30
SELECT 
      a.tablespace_name, 
      round(100 - round((a.free_kb/b.size_kb) * 100,2),2) as "Used Pct",
      round(b.size_kb/1024/1024,2) as "Size_GB",
      round(a.free_kb/1024/1024,2) as "Free_GB",
      round(((a.free_kb/b.size_kb) * 100),2) as "Free_Pct",
      round(b.sizeMax_kb/1024/1024,2) as "Max_GB",
      round(100 -round(((b.sizeMax_kb-b.size_kb+a.free_kb)/b.sizeMax_kb) * 100), 2) as "Used_PctMax"
FROM (SELECT tablespace_name,
             TRUNC(SUM(bytes)/1024,2) free_kb 
             FROM dba_free_space GROUP BY tablespace_name) a,
     (SELECT tablespace_name,
             TRUNC(SUM(bytes)/1024,2) size_kb,
             TRUNC(SUM(decode(AUTOEXTENSIBLE,'NO',bytes,'YES',MAXBYTES)/1024)) sizeMax_kb
      FROM dba_data_files GROUP BY tablespace_name) b 
WHERE a.tablespace_name = b.tablespace_name 
union
SELECT  d.tablespace_name "Name",
round((t.bytes / a.bytes * 100), 2) "Used %",
round(a.bytes/1024/1024/1024, 2) "Size (GM)", 
round(((a.bytes - t.bytes)/1024/1024/1024),2)  "Free (GM)",
(100 - round(((t.bytes / a.bytes )* 100), 2)) "Free %",
round(a.sizeMax_kb/1024/1024,2)  "MaxSize (GB)",
(100 - round((((a.sizeMax_kb- t.bytes/1024)/a.sizeMax_kb)*100),2)) "Used_PctMax"
FROM sys.dba_tablespaces d, (select tablespace_name, sum(bytes) bytes, TRUNC(SUM(decode(AUTOEXTENSIBLE,'NO',bytes,'YES',MAXBYTES)/1024)) sizeMax_kb 
from dba_temp_files group by tablespace_name) a,
(select tablespace_name, sum(bytes_cached) bytes from v$temp_extent_pool group by tablespace_name) t
WHERE d.tablespace_name = a.tablespace_name(+) AND d.tablespace_name = t.tablespace_name(+)
AND d.extent_management like 'LOCAL' AND d.contents like 'TEMPORARY'
order by 2 desc;



--------------------------------------------------------------------
prompt 18. Revision de la frecuencia de archives de los ultimos dias.
--------------------------------------------------------------------

REM Generacion de Archives
REM instancia 1
set lines 220;
set pages 999;
select to_char(first_time,'DD-MON-RR') "Date",
to_char(sum(decode(to_char(first_time,'HH24'),'00',1,0)),'999') " 00",
to_char(sum(decode(to_char(first_time,'HH24'),'01',1,0)),'999') " 01",
to_char(sum(decode(to_char(first_time,'HH24'),'02',1,0)),'999') " 02",
to_char(sum(decode(to_char(first_time,'HH24'),'03',1,0)),'999') " 03",
to_char(sum(decode(to_char(first_time,'HH24'),'04',1,0)),'999') " 04",
to_char(sum(decode(to_char(first_time,'HH24'),'05',1,0)),'999') " 05",
to_char(sum(decode(to_char(first_time,'HH24'),'06',1,0)),'999') " 06",
to_char(sum(decode(to_char(first_time,'HH24'),'07',1,0)),'999') " 07",
to_char(sum(decode(to_char(first_time,'HH24'),'08',1,0)),'999') " 08",
to_char(sum(decode(to_char(first_time,'HH24'),'09',1,0)),'999') " 09",
to_char(sum(decode(to_char(first_time,'HH24'),'10',1,0)),'999') " 10",
to_char(sum(decode(to_char(first_time,'HH24'),'11',1,0)),'999') " 11",
to_char(sum(decode(to_char(first_time,'HH24'),'12',1,0)),'999') " 12",
to_char(sum(decode(to_char(first_time,'HH24'),'13',1,0)),'999') " 13",
to_char(sum(decode(to_char(first_time,'HH24'),'14',1,0)),'999') " 14",
to_char(sum(decode(to_char(first_time,'HH24'),'15',1,0)),'999') " 15",
to_char(sum(decode(to_char(first_time,'HH24'),'16',1,0)),'999') " 16",
to_char(sum(decode(to_char(first_time,'HH24'),'17',1,0)),'999') " 17",
to_char(sum(decode(to_char(first_time,'HH24'),'18',1,0)),'999') " 18",
to_char(sum(decode(to_char(first_time,'HH24'),'19',1,0)),'999') " 19",
to_char(sum(decode(to_char(first_time,'HH24'),'20',1,0)),'999') " 20",
to_char(sum(decode(to_char(first_time,'HH24'),'21',1,0)),'999') " 21",
to_char(sum(decode(to_char(first_time,'HH24'),'22',1,0)),'999') " 22",
to_char(sum(decode(to_char(first_time,'HH24'),'23',1,0)),'999') " 23"
from gv$log_history WHERE first_time > TRUNC (sysdate - 13) and inst_id=1 group by to_char(first_time,'DD-MON-RR') 
order by 1
/

REM Generacion de Archives
REM instancia 1
set lines 220;
set pages 999;
select to_char(first_time,'DD-MON-RR') "Date",
to_char(sum(decode(to_char(first_time,'HH24'),'00',1,0)),'999') " 00",
to_char(sum(decode(to_char(first_time,'HH24'),'01',1,0)),'999') " 01",
to_char(sum(decode(to_char(first_time,'HH24'),'02',1,0)),'999') " 02",
to_char(sum(decode(to_char(first_time,'HH24'),'03',1,0)),'999') " 03",
to_char(sum(decode(to_char(first_time,'HH24'),'04',1,0)),'999') " 04",
to_char(sum(decode(to_char(first_time,'HH24'),'05',1,0)),'999') " 05",
to_char(sum(decode(to_char(first_time,'HH24'),'06',1,0)),'999') " 06",
to_char(sum(decode(to_char(first_time,'HH24'),'07',1,0)),'999') " 07",
to_char(sum(decode(to_char(first_time,'HH24'),'08',1,0)),'999') " 08",
to_char(sum(decode(to_char(first_time,'HH24'),'09',1,0)),'999') " 09",
to_char(sum(decode(to_char(first_time,'HH24'),'10',1,0)),'999') " 10",
to_char(sum(decode(to_char(first_time,'HH24'),'11',1,0)),'999') " 11",
to_char(sum(decode(to_char(first_time,'HH24'),'12',1,0)),'999') " 12",
to_char(sum(decode(to_char(first_time,'HH24'),'13',1,0)),'999') " 13",
to_char(sum(decode(to_char(first_time,'HH24'),'14',1,0)),'999') " 14",
to_char(sum(decode(to_char(first_time,'HH24'),'15',1,0)),'999') " 15",
to_char(sum(decode(to_char(first_time,'HH24'),'16',1,0)),'999') " 16",
to_char(sum(decode(to_char(first_time,'HH24'),'17',1,0)),'999') " 17",
to_char(sum(decode(to_char(first_time,'HH24'),'18',1,0)),'999') " 18",
to_char(sum(decode(to_char(first_time,'HH24'),'19',1,0)),'999') " 19",
to_char(sum(decode(to_char(first_time,'HH24'),'20',1,0)),'999') " 20",
to_char(sum(decode(to_char(first_time,'HH24'),'21',1,0)),'999') " 21",
to_char(sum(decode(to_char(first_time,'HH24'),'22',1,0)),'999') " 22",
to_char(sum(decode(to_char(first_time,'HH24'),'23',1,0)),'999') " 23"
from gv$log_history WHERE first_time > TRUNC(sysdate - 13) and inst_id=2 group by to_char(first_time,'DD-MON-RR') 
order by 1
/

prompt Numero de Archives generado

 
select to_char(COMPLETION_TIME,'DD-MON-YYYY') "Date",count(*) , trunc(SUM(BLOCKS * BLOCK_SIZE)/1024/1024 ,2)SIZE_MB from gv$archived_log 
where COMPLETION_TIME > TRUNC(sysdate - 7)  AND INST_ID=1 group by to_char(COMPLETION_TIME,'DD-MON-YYYY') order by 1;

select to_char(COMPLETION_TIME,'DD-MON-YYYY') "Date",count(*) , trunc(SUM(BLOCKS * BLOCK_SIZE)/1024/1024 ,2)SIZE_MB from gv$archived_log 
where COMPLETION_TIME > TRUNC(sysdate - 7) AND INST_ID=2 group by to_char(COMPLETION_TIME,'DD-MON-YYYY') order by 1;
--order by completion_time;
--order by to_date(to_char(COMPLETION_TIME,'DD-MON-YYYY'),'dd-mon-yyy');

select to_char(COMPLETION_TIME,'DD-MON-YYYY') "Date",--count(*) ,
 trunc((BLOCKS * BLOCK_SIZE)/1024/1024 ,2) SIZE_MB from v$archived_log 
where COMPLETION_TIME > TRUNC(sysdate - 2)   group by to_char(COMPLETION_TIME,'DD-MON-YYYY') order by 1;

select / as sysdba


--------------------------------------------------------------------
prompt 19. Revision del AAS
--------------------------------------------------------------------
show parameter cpu

--AAS
SET LINESIZE 1200
SET PAGESIZE 200

COLUMN DAY   FORMAT A06
COLUMN H00   FORMAT 999.9     HEADING '00'
COLUMN H01   FORMAT 999.9     HEADING '01'
COLUMN H02   FORMAT 999.9     HEADING '02'
COLUMN H03   FORMAT 999.9     HEADING '03'
COLUMN H04   FORMAT 999.9     HEADING '04'
COLUMN H05   FORMAT 999.9     HEADING '05'
COLUMN H06   FORMAT 999.9     HEADING '06'
COLUMN H07   FORMAT 999.9     HEADING '07'
COLUMN H08   FORMAT 999.9     HEADING '08'
COLUMN H09   FORMAT 999.9     HEADING '09'
COLUMN H10   FORMAT 999.9     HEADING '10'
COLUMN H11   FORMAT 999.9     HEADING '11'
COLUMN H12   FORMAT 999.9     HEADING '12'
COLUMN H13   FORMAT 999.9     HEADING '13'
COLUMN H14   FORMAT 999.9     HEADING '14'
COLUMN H15   FORMAT 999.9     HEADING '15'
COLUMN H16   FORMAT 999.9     HEADING '16'
COLUMN H17   FORMAT 999.9     HEADING '17'
COLUMN H18   FORMAT 999.9     HEADING '18'
COLUMN H19   FORMAT 999.9     HEADING '19'
COLUMN H20   FORMAT 999.9     HEADING '20'
COLUMN H21   FORMAT 999.9     HEADING '21'
COLUMN H22   FORMAT 999.9     HEADING '22'
COLUMN H23   FORMAT 999.9     HEADING '23'
COLUMN TOTAL FORMAT 999.9     HEADING 'Total'

SELECT
SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH:MI:SS'),1,5)                          DAY
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'00',AAS)) H00
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'01',AAS)) H01
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'02',AAS)) H02
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'03',AAS)) H03
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'04',AAS)) H04
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'05',AAS)) H05
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'06',AAS)) H06
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'07',AAS)) H07
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'08',AAS)) H08
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'09',AAS)) H09
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'10',AAS)) H10
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'11',AAS)) H11
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'12',AAS)) H12
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'13',AAS)) H13
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'14',AAS)) H14
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'15',AAS)) H15
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'16',AAS)) H16
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'17',AAS)) H17
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'18',AAS)) H18
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'19',AAS)) H19
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'20',AAS)) H20
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'21',AAS)) H21
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'22',AAS)) H22
, MAX(DECODE(SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH24:MI:SS'),10,2),'23',AAS)) H23
, ROUND(avg(aas),2) AVG_DAY
fROM  ibm.IBM_HISTORIAL_TIEMPO_RESPUESTA  a WHERE TO_CHAR(fecha, 'YYYYMM')='201707'
GROUP BY SUBSTR(TO_CHAR(fecha, 'MM/DD/RR HH:MI:SS'),1,5) order by 1

/


--------------------------------------------------------
prompt Tempfiles
--------------------------------------------------------
 
select file_name, autoextensible, tablespace_name, ROUND(bytes/1024/1024,2) "DbSizeMb",ROUND(maxbytes/1024/1024,2) "MaxSizeMb" 
from dba_temp_files order by tablespace_name, file_name;

--------------------------------------------------------
prompt Status Tempfiles
--------------------------------------------------------

SET PAGESIZE 60
SET LINESIZE 300
 
SELECT 
   A.tablespace_name tablespace, 
   D.mb_total,
   SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_used,
   D.mb_total - SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_free
FROM 
   v$sort_segment A,
(
SELECT 
   B.name, 
   C.block_size, 
   SUM (C.bytes) / 1024 / 1024 mb_total
FROM 
   v$tablespace B, 
   v$tempfile C
WHERE 
   B.ts#= C.ts#
GROUP BY 
   B.name, 
   C.block_size
) D
WHERE 
   A.tablespace_name = D.name
GROUP by 
   A.tablespace_name, 
   D.mb_total
/

--------------------------------------------------------
prompt Tablespace UNDO
--------------------------------------------------------

col "Extend Management" format a20
col  "Segment Space Management" format a30
select TABLESPACE_NAME, STATUS, EXTENT_MANAGEMENT "Extend Management", SEGMENT_SPACE_MANAGEMENT "Segment Space Management", RETENTION from dba_tablespaces 
where tablespace_name in (select value from v$parameter where name='undo_tablespace');

--------------------------------------------------------
prompt Advisor UNDO
--------------------------------------------------------

SELECT d.undo_size/(1024*1024) "ACTUAL UNDO SIZE [MByte]",
SUBSTR(e.value,1,25) "UNDO RETENTION [Sec]",
ROUND((d.undo_size / (to_number(f.value) *
g.undo_block_per_sec))) "OPTIMAL UNDO RETENTION [Sec]"
FROM (
SELECT SUM(a.bytes) undo_size
FROM v$datafile a,
v$tablespace b,
dba_tablespaces c
WHERE c.contents = 'UNDO'
AND c.STATUS = 'ONLINE'
AND b.name = c.tablespace_name
AND a.ts# = b.ts#
) d,
v$parameter e,
v$parameter f,
(
SELECT MAX(undoblks/((end_time-begin_time)*3600*24))
undo_block_per_sec
FROM v$undostat
) g
WHERE e.name = 'undo_retention'
AND f.name = 'db_block_size';



--------------------------------------------------------
prompt Uso session_cached_cursors 
--------------------------------------------------------
col value format a10
col USAGE format a10
SELECT 'session_cached_cursors' parameter, lpad(VALUE, 5) VALUE,  decode(VALUE, 0, '  n/a', to_char(100 * used / VALUE, '990') || '%') usage  
FROM (SELECT MAX(s.VALUE) used  FROM v$statname n, v$sesstat s  WHERE n.NAME = 'session cursor cache count'  AND s.statistic# = n.statistic#),  
(SELECT VALUE FROM v$parameter WHERE NAME = 'session_cached_cursors')  
UNION ALL  SELECT 'open_cursors',  lpad(VALUE, 5),  to_char(100 * used / VALUE, '990') || '%'  FROM (SELECT MAX(SUM(s.VALUE)) used  
FROM v$statname n, v$sesstat s  WHERE n.NAME IN  ('opened cursors current', 'session cursor cache count')  AND s.statistic# = n.statistic#  
GROUP BY s.sid),  (SELECT VALUE FROM v$parameter WHERE NAME = 'open_cursors');

-- sesiones por instancia

select inst_id, username, MACHINE, count(*) from gv$session where username is not null group by inst_id, username,machine order by 1,2,3;

--sesiones por día

select ROUND(avg(cantidad),0) sesiones from ibm.ibm_historial_sesiones
where  substr(fecha,1,6)='201707'
group by substr(fecha,1,8)
order by substr(fecha,1,8);


    
--------------------------------------------------------
prompt Uso de Session y Process / Resource_Limit
--------------------------------------------------------
col "Limit_Value" format a15
select INST_ID, RESOURCE_NAME, CURRENT_UTILIZATION as "Current",MAX_UTILIZATION as "Max_Used", LIMIT_VALUE as "Limit_Value" from gv$resource_limit 
where RESOURCE_NAME in ('processes','sessions','transactions') order by 1;



--------------------------------------------------------
prompt Uso de Parametros
--------------------------------------------------------
set line 100
col name format a40
col value format a50
select name, VALUE from v$parameter where name in ('audit_trail','cursor_sharing','statistics_level','db_recovery_file_dest','db_recovery_file_dest_size',
'optimizer_mode','sec_max_failed_login_attempts','sec_case_sensitive_logon','optimizer_use_invisible_indexes','optimizer_use_pending_statistics','optimizer_index_cost_adj',
'optimizer_features_enable','undo_management','undo_retention','undo_tablespace','db_block_size') order by 1;


prompt FRA

SELECT a.name, ROUND((A.SPACE_LIMIT / 1024 / 1024 / 1024), 2) AS "FraTotalGB",ROUND((A.SPACE_USED / 1024 / 1024 / 1024), 2) AS "FraUsedGB",ROUND((A.SPACE_RECLAIMABLE / 1024 / 1024 / 1024), 2) 
AS "FraReclaimableGB", SUM(B.PERCENT_SPACE_USED) AS PERCENT_OF_SPACE_USED FROM V$RECOVERY_FILE_DEST A, V$FLASH_RECOVERY_AREA_USAGE B 
GROUP BY name, SPACE_LIMIT, SPACE_USED , SPACE_RECLAIMABLE ;

prompt backups

         select session_key,
                input_type,
                status,
                to_char(start_time,'yyyy-mm-dd hh24:mi') start_time,
                to_char(end_time,'yyyy-mm-dd hh24:mi')   end_time,
                output_bytes_display,
                output_device_type,
                 time_taken_display,
                optimized
         from v$rman_backup_job_details
         where trunc(start_time) >= trunc(sysdate-7) --desde hace 10 dias
         --and input_type  like 'DB FULL%'
          --and input_type  <> 'ARCHIVELOG'
          --and  status <> 'FAILED'
          order by session_key asc;


--------------------------------------------------------
prompt Status Username
--------------------------------------------------------
select username, account_status, LOCK_DATE, EXPIRY_DATE, profile from dba_users where username NOT in 
('SYS','SYSMAN','ANONYMOUS','APPQOSSYS','CTXSYS','DBSNMP','DIP','DMSYS','EXFSYS','HR','MDDATA','MDSYS',
'OLAPSYS','ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS', 'OUTLN','SCOTT','SI_INFORMTN_SCHEMA','SPATIAL_CSW_ADMIN_USR',
'SPATIAL_WFS_ADMIN_USR','TSMSYS','WMSYS','XDB','XS$NULL','SYS','SYSTEM','APEX_030200','ORDDATA','FLOWS_FILES', 
'OWBSYS_AUDIT', 'APEX_PUBLIC_USER','OWBSYS','MGMT_VIEW') order by 5,1;


select username, account_status, profile from dba_users where username NOT in ('SYS','SYSMAN','ANONYMOUS','APPQOSSYS',
'CTXSYS','DBSNMP','DIP','DMSYS','EXFSYS','HR','MDDATA','MDSYS','OLAPSYS','ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS', 
'OUTLN','SCOTT','SI_INFORMTN_SCHEMA','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','TSMSYS','WMSYS','XDB','XS$NULL',
'SYS','SYSTEM','APEX_030200','ORDDATA','FLOWS_FILES', 
'OWBSYS_AUDIT', 'APEX_PUBLIC_USER','OWBSYS','MGMT_VIEW') order by 3,1;


--------------------------------------------------------
prompt Profiles
--------------------------------------------------------
select PROFILE, RESOURCE_NAME, LIMIT from dba_profiles where RESOURCE_NAME in ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME',
'SESSIONS_PER_USER','PASSWORD_LIFE_TIME','PASSWORD_LOCK_TIME','PASSWORD_VERIFY_FUNCTION') order by 1,2;

select PROFILE, RESOURCE_NAME, LIMIT from dba_profiles where RESOURCE_NAME in ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME',
'SESSIONS_PER_USER','PASSWORD_LIFE_TIME','PASSWORD_LOCK_TIME','PASSWORD_VERIFY_FUNCTION') and 
PROFILE='DEFAULT' order by 1,2;
--------------------------------------------------------
prompt Fragmentacion de Tablas
--------------------------------------------------------

SELECT t.OWNER||'.'||t.TABLE_NAME as "TableName",
         t.TABLESPACE_NAME,
         t.NUM_ROWS,
         ROUND (
              (  ( (t.BLOCKS * 8192) - (t.NUM_ROWS * t.AVG_ROW_LEN))
               / (t.BLOCKS * 8192))
            * 100,
            2)
            AS TAB_FRAG,
         round(t.BLOCKS * 8192 / 1024 / 1024,2) AS MB
    FROM    ALL_TABLES t
         JOIN
            ALL_OBJECTS o
         ON (    t.TABLE_NAME = o.OBJECT_NAME
             AND t.OWNER = o.OWNER
             AND o.OBJECT_TYPE = 'TABLE'
             AND o.owner NOT IN
                    ('SYS', 'SYSTEM', 'SYSMAN', 'TSMSYS', 'DBSNMP', 'OUTLN'))
   WHERE     t.BLOCKS >= 50
         AND   (  (  ( (t.BLOCKS * 8192) - (t.NUM_ROWS * t.AVG_ROW_LEN))
                   / (t.BLOCKS * 8192))
                * 100)
             - t.PCT_FREE > 10
                         order by 4 desc;
--ORDER BY owner, MB DESC;


-------------------------------------------------------
prompt DBMS_SPACE Recomendaciones
--------------------------------------------------------

SELECT * FROM TABLE (DBMS_SPACE.asa_recommendations ('FALSE', 'FALSE', 'FALSE'));

--------------------------------------------------------
prompt Tablespace con Fragmentacion
--------------------------------------------------------

select tablespace_name, 
round(allocated_space/1024/1024,0) allocated_space_mb, 
round(reclaimable_space/1024/1024,0) reclaimable_space_mb
from table(dbms_space.asa_recommendations('TRUE', 'TRUE', 'ALL'))
order by reclaimable_space desc;

--------------------------------------------------------
prompt Segmentos con Fragmentacion
--------------------------------------------------------

SELECT SEGMENT_OWNER,segment_name,
round(allocated_space/1024/1024,1) allocated_space_mb,
rounMIN_USR','SPATIAL_WFS_ADMIN_USR','TSMSYS','WMSYS','XDB','XS$NULL','SYS','SYSTEM','APEX_030200','ORDDATA','FLOWS_FILES', 
'OWBSYS_AUDIT', 'APEX_PUBLIC_USER','OWBSYS')
group by index_owner,trunc(last_analyzed)
order by Total desc)
where rownum<30;

-------------------------------------------------------
PROMPT  Verificacion Files Database
----------------------------------------------
set pagesize 300
select 'File Type' as "File Type", 'Location' As "Location" from dual
union select distinct 'Datafiles', (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1)))  from dba_data_files 
union select distinct 'Tempfiles', (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) from dba_temp_files 
union select distinct 'Flash Recover Area' , value from v$parameter where name='db_recovery_file_dest' 
union select distinct 'Redo Logs' , (SUBSTR(member,1,INSTR(member,'\',-1,1))) from v$logfile 
union select distinct 'Controlfiles' ,(SUBSTR(name,1,INSTR(name,'\',-1,1))) from v$controlfile;

set pagesize 300
set line 150
select 'File Type' as "File Type", 'Location' As "Location", 'Tamaño' as "Size MB" from dual union 
select 'Datafiles', (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))), To_char(trunc(sum(bytes/1024/1024))) 
from dba_data_files group by  (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) union select distinct 'Tempfiles', (SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) , to_char(trunc(sum(bytes/1024/1024))) from dba_temp_files group by SUBSTR(file_name,1,INSTR(file_name,'\',-1,1)) union
select  'Flash Recover Area', name , to_char(trunc(space_used/1024/1024))from v$recovery_file_dest  union select distinct 'Redo Logs' , (SUBSTR(a.member,1,INSTR(member,'\',-1,1))), to_char(sum(b.BYTES/1024/1024)) 
from v$logfile a, v$log b where a.group#=b.group# group by SUBSTR(a.member,1,INSTR(member,'\',-1,1)) union 
select  'Controlfiles' ,(SUBSTR(name,1,INSTR(name,'\',-1,1))), to_char(trunc(sum(BLOCK_SIZE*FILE_SIZE_BLKS/1024/1024))) from v$controlfile group by SUBSTR(name,1,INSTR(name,'\',-1,1)) ;


--------------------------------------
PROMPT SIZE DATABASE ON SERVER
---------------------------------------
col FileName format a60 
select a.filename "FileName", trunc(sum(a.sizemb)) "SizeMb" from
 ((select SUBSTR(file_name,1,INSTR(file_name,'\',-1,1)) filename, sum(bytes/1024/1024) sizemb  from dba_data_files 
group by SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) union 
(select SUBSTR(file_name,1,INSTR(file_name,'\',-1,1)) filename, sum(bytes/1024/1024) sizemb  from dba_temp_files  
group by SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) union 
(select name , space_used/1024/1024 sizemb from v$recovery_file_dest ) union 
(select SUBSTR(a.member,1,INSTR(member,'\',-1,1)) filename, sum(b.BYTES/1024/1024) sizemb from v$logfile a, v$log b  
where a.group#=b.group# group by SUBSTR(a.member,1,INSTR(member,'\',-1,1))) union 
(select SUBSTR(name,1,INSTR(name,'\',-1,1)) filename, sum(BLOCK_SIZE*FILE_SIZE_BLKS/1024/1024) sizemb from v$controlfile 
 group by SUBSTR(name,1,INSTR(name,'\',-1,1))) ) a group by a.filename order by 1;

------------------------------------------
Prompt  espacio de filesistem del servidor
-------------------------------------------
select * from jt.particiones;

-----------------------------------------------------------
PROMPT  Verificacion de Tablas e Indices por File System
-----------------------------------------------------------

col "File Name" format a60
set line 200
SET PAGESIZE 100

select distinct(SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) as "File Name", b.tablespace_name , b.owner, count(*) as "Nro Indexes" 
from dba_data_files a, dba_segments b
where a.tablespace_name =b.tablespace_name and b.segment_type='INDEX'
and b.owner 
NOT in ('SYS','SYSMAN','ANONYMOUS','APPQOSSYS','CTXSYS','DBSNMP','DIP','DMSYS','EXFSYS','HR','MDDATA','MDSYS','OLAPSYS','ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS', 
'OUTLN','SCOTT','SI_INFORMTN_SCHEMA','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','TSMSYS','WMSYS','XDB','XS$NULL','SYS','SYSTEM','APEX_030200','ORDDATA','FLOWS_FILES', 
'OWBSYS_AUDIT', 'APEX_PUBLIC_USER','OWBSYS')
 Group by a.file_name, b.tablespace_name,b.owner order by 4 desc ,3 desc;

col "File Name" format a60
set line 200
SET PAGESIZE 100

select distinct(SUBSTR(file_name,1,INSTR(file_name,'\',-1,1))) as "File Name", b.tablespace_name , b.owner, count(*) as "Nro Tablas" 
from dba_data_files a, dba_segments b
where a.tablespace_name =b.tablespace_name and b.segment_type='TABLE'
and b.owner 
NOT in ('SYS','SYSMAN','ANONYMOUS','APPQOSSYS','CTXSYS','DBSNMP','DIP','DMSYS','EXFSYS','HR','MDDATA','MDSYS','OLAPSYS','ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS', 
'OUTLN','SCOTT','SI_INFORMTN_SCHEMA','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','TSMSYS','WMSYS','XDB','XS$NULL','SYS','SYSTEM','APEX_030200','ORDDATA','FLOWS_FILES', 
'OWBSYS_AUDIT', 'APEX_PUBLIC_USER','OWBSYS')
 Group by a.file_name, b.tablespace_name,b.owner order by 4 desc ,3 desc;


prompt top sql
-------------------

SELECT * FROM
(SELECT
    sql_fulltext,
    sql_id,
    elapsed_time,
    child_number,
    disk_reads,
    executions,
    first_load_time,
    last_load_time
FROM    v$sql
ORDER BY elapsed_time DESC)
WHERE ROWNUM < 10
/

spool off
exit

