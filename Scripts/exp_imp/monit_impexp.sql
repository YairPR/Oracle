impdp  "' / as sysdba'" dumpfile=DMP_SYSFIS08112020.dmp  logfile=DMP_SYSFIS08112020.log  directory=DMP_SYS_FIS_4 table_exists_action=TRUNCATE  TRANSFORM=DISABLE_ARCHIVE_LOGGING:Y LOGTIME=ALL


alter session set nls_date_format='DD-MON-YYYY hh24:mi:ss';
set line 1000
column Device format a5
column type format a10
column filename format a70
column status format a15
column open for 9999999999999999
column close for 9999999999999999
select device_type "Device", type , filename, status, bytes/1048576000 sizeGB
, to_char(open_time, 'mm/dd/yyyy hh24:mi:ss') open,
to_char(close_time,'mm/dd/yyyy hh24:mi:ss') close ,
elapsed_time/6000 ETmts, 
effective_bytes_per_second EPS
 from v$backup_async_io where filename like '%restore%';


SET pagesize 800
SET linesize 800
COL OPNAME FORMAT A15
COL USERNAME FORMAT A10
COL START_TIME FORMAT A14
COL END_TIME FORMAT A14
COL SEG FORMAT 999999
COL OBJETO FORMAT A5
COL SID FORMAT 999
COL SERIAL FORMAT 99999
COL BYTES 99999
COL BYTES_TOT FORMAT 99999999999
COL PCT FORMAT A6
COL TOT_HR FORMAT A9
COL TOT_MI FORMAT A10
COL FALTA FORMAT A14
select substr(OPNAME,0,15)OPNAME,USERNAME,TO_CHAR(START_TIME,'dd/mm hh24:mi:ss') START_TIME,TO_CHAR(LAST_UPDATE_TIME,'dd/mm hh24:mi:ss') END_TIME,ELAPSED_SECONDS SEG,
TARGET OBJETO,SID,SERIAL# SERIAL,SOFAR BYTES,TOTALWORK BYTES_TOT,
ROUND((SOFAR/TOTALWORK)*100,2)||'%' PCT,(ROUND(ELAPSED_SECONDS/60/60,2))||'Hrs.' TOT_HR,(ROUND(ELAPSED_SECONDS/60,2))||'Min.' TOT_MI,
(ROUND(TIME_REMAINING/60,2))||' Min.' FALTA
from v$session_longops where TOTALWORK> 0 and OPNAME LIKE '%IMPORT%';


set lines 300 pages 20000
set verify off
col inst_id for 99
col os_db_user for a20
col sid_serial for a14
col last_Execution for a8
col module for a32
col kill_pid for a16
col query for a30
col machine for a20
col logon_time for a17
col program for a37
col event for a16
col last_call for 99999
undefine w_sid
SELECT UPPER(s.OsUser) || ' ' || s.UserName os_db_user,
       s.sid || ',' || s.serial# sid_serial,
       to_char(sysdate-(s.last_call_et/(24*3600)), 'hh24:mi:ss') last_Execution,
       substr(s.module, 1, 32) module,
       s.status,
       'kill -9 '|| p.spid kill_pid, 
       '@s '|| s.sql_address || ' '|| s.sql_hash_value QUERY,
       s.machine , 
       to_char(LOGON_TIME, 'YY-MM-DD HH24:MI:SS') logon_time,
       substr(s.Program, 1, 24) || '-' || substr(s.action, 1, 12) program,
       LAST_CALL_ET/60 last_call
FROM v$Session s , v$process p 
WHERE p.addr = s.paddr
  and s.sid = &&w_sid;
undef w_sid
set verify on



select
owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024,2) as "Object Size (Mb)"
, tablespace_name as "Tablespace"
from dba_segments
where segment_name='&tab_name';
