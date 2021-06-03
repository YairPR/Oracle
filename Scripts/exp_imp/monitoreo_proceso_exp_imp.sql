ORACLE 	11.2.0.4 	172.23.14.82 	rsdcatdbtest01
oracle c4mpus$.


-----------------------------------------------------------------------------------
Validar a nivel de log del import
-----------------------------------------------------------------------------------
/backuptmp/BDCONTA_Ago18/data    archivo log import_BDCONTA_RESTORE_2018.log


-----------------------------------------------------------------------------------
Validar a nivel de proceso
-----------------------------------------------------------------------------------
ps -ef | grep 5243446
  oracle 45613430        1   0 00:52:15      -  0:00 impdp '/ as sysdba ' DIRECTORY=IMPORT full=Y DUMPFILE=BDCONTA_11072018.dmp%U LOGFILE=import_BDCONTA_RESTORE_2018.log REMAP_TABLESPACE=UNDOTBS:UNDOTBS1 TABLE_EXISTS_ACTION=REPLACE
  oracle 62259590 47448446   0 08:07:43 pts/15  0:00 grep 45613430
  oracle  9175750 45613430   0 00:52:15      -  0:03 oracleBDCONTA2 (DESCRIPTION=(LOCAL=YES)(ADDRESS=(PROTOCOL=beq)))
[oracle@rsdcatdbtest01]/home/oracle> 
[oracle@rsdcatdbtest01]/home/oracle> 


-----------------------------------------------------------------------------------
Validar a nivel de avance de import data
-----------------------------------------------------------------------------------

SELECT sl.sid, sl.serial#, sl.sofar, sl.totalwork, dp.owner_name, dp.state, dp.job_mode
FROM v$session_longops sl, v$datapump_job dp
WHERE sl.opname = dp.job_name
AND sl.sofar != sl.totalwork;


-----------------------------------------------------------------------------------
Validar a nivel de consola impdp
-----------------------------------------------------------------------------------

impdp "'/ as sysdba'" attach=SYS_IMPORT_TABLE_01




-----------------------------------------------------------------------------------
Validar eventos de espera en la bd
-----------------------------------------------------------------------------------

select ERROR_MSG from DBA_RESUMABLE;



-----------------------------------------------------------------------------------
Validar si el job sigue corriendo
-----------------------------------------------------------------------------------

SELECT owner_name, job_name, operation, job_mode, state
FROM dba_datapump_jobs;


-----------------------------------------------------------------------------------
Validar espacios en tablespaces
-----------------------------------------------------------------------------------

set linesize 600
set pagesize 500
COLUMN TBS format a25
SELECT substr(a.tablespace_name,0,25) TBS, ROUND (a.bytes_alloc / 1024 / 1024, 2) TOTAL_SPACE_MB,
 ROUND (NVL (b.bytes_free, 0) / 1024 / 1024, 2) FREE_SPACE_MB,
 ROUND ((a.bytes_alloc - NVL (b.bytes_free, 0)) / 1024 / 1024,2)megs_used,
 ROUND ((NVL (b.bytes_free, 0) / a.bytes_alloc) * 100, 2) pct_free,
 100 - ROUND ((NVL (b.bytes_free, 0) / a.bytes_alloc) * 100, 2) pct_used,
 ROUND (maxbytes / 1048576, 2) MAX
 FROM (SELECT f.tablespace_name, SUM (f.BYTES) bytes_alloc,
 SUM (DECODE (f.autoextensible,'YES', f.maxbytes,'NO', f.BYTES)) maxbytes
 FROM dba_data_files f
 GROUP BY tablespace_name) a,
 (SELECT f.tablespace_name, SUM (f.BYTES) bytes_free
 FROM dba_free_space f
 GROUP BY tablespace_name) b
 WHERE a.tablespace_name = b.tablespace_name and a.tablespace_name not in (select tablespace_name from dba_tablespaces where contents='UNDO')
 order by 5 desc;
 set feedback on;
 set feedback off;
 set linesize 600
set pagesize 500
COLUMN TBS format a25
SELECT substr(a.tablespace_name,0,25) TBS, ROUND (a.bytes_alloc / 1024 / 1024, 2) TOTAL_SPACE_MB,
 ROUND (NVL (b.bytes_free, 0) / 1024 / 1024, 2) FREE_SPACE_MB,
 ROUND ((a.bytes_alloc - NVL (b.bytes_free, 0)) / 1024 / 1024,2)megs_used,
 ROUND ((NVL (b.bytes_free, 0) / a.bytes_alloc) * 100, 2) pct_free,
 100 - ROUND ((NVL (b.bytes_free, 0) / a.bytes_alloc) * 100, 2) pct_used,
 ROUND (maxbytes / 1048576, 2) MAX
 FROM (SELECT f.tablespace_name, SUM (f.BYTES) bytes_alloc,
 SUM (DECODE (f.autoextensible,'YES', f.maxbytes,'NO', f.BYTES)) maxbytes
 FROM dba_data_files f
 GROUP BY tablespace_name) a,
 (SELECT f.tablespace_name, SUM (f.BYTES) bytes_free
 FROM dba_free_space f
 GROUP BY tablespace_name) b
 WHERE a.tablespace_name = b.tablespace_name and a.tablespace_name in (select tablespace_name from dba_tablespaces where contents='UNDO')
 order by 5 desc; 
 SELECT h.tablespace_name,
 ROUND (SUM (h.bytes_free + h.bytes_used) / 1048576, 2) TOTAL_SPACE_MB,
 ROUND ( SUM ((h.bytes_free + h.bytes_used) - NVL (h.bytes_used, 0))/1048576,2) FREE_SPACE_MB,
 ROUND (SUM (NVL (h.bytes_used, 0)) / 1048576, 2) megs_used,
 ROUND ( ( SUM ( (h.bytes_free + h.bytes_used)- NVL (h.bytes_used, 0))/ SUM (h.bytes_used + h.bytes_free))* 100,2) pct_free,
 100 - ROUND ( ( SUM ( (h.bytes_free + h.bytes_used)- NVL (h.bytes_used, 0))/ SUM (h.bytes_used + h.bytes_free))* 100,2) pct_used,
 ROUND (f.maxbytes / 1048576, 2) MAX
 FROM SYS.v_$temp_space_header h,SYS.v_$temp_extent_pool p,dba_temp_files f
 WHERE p.file_id(+) = h.file_id
 AND p.tablespace_name(+) = h.tablespace_name
 AND f.file_id = h.file_id
 AND f.tablespace_name = h.tablespace_name
 GROUP BY h.tablespace_name, f.maxbytes
 (+) order by 5 desc;
 set feedback on;


-----------------------------------------------------------------------------------
Validar errores en alert log
-----------------------------------------------------------------------------------
/oracle/app/oracle/diag/rdbms/bdconta2/BDCONTA2/trace/alert_BDCONTA2.log


