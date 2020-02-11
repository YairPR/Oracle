-----------------------------------------------
prompt Archive MODE
-----------------------------------------------
archive log list;
-----------------------------------------------
prompt Configuracion de Backups
-----------------------------------------------
col start_time format a30
set pagesize 2000
set linesize 400
select SESSION_KEY, INPUT_TYPE, STATUS,
 to_char(START_TIME,'mm/dd/yy hh24:mi') start_time,
 to_char(END_TIME,'mm/dd/yy hh24:mi') end_time,
 OUTPUT_DEVICE_TYPE "OUTPUT_DEVICE",
 elapsed_seconds/3600 hrs
 from V$RMAN_BACKUP_JOB_DETAILS
 order by session_key;
-----------------------------------------------
prompt RedoLogs Multiplexado
-----------------------------------------------
select member from v$logfile;
-----------------------------------------------
prompt Configuracion de Redologs
-----------------------------------------------
select group#,members,bytes/1024/1024 "MB" from V$log;
-----------------------------------------------
prompt Tamanio de log buffer
-----------------------------------------------
show parameter log_buffer
-----------------------------------------------
prompt Configuracion de ASMM
-----------------------------------------------
show parameter sga
show parameter pga
show parameter memory
-----------------------------------------------
prompt Configuracion de Large Pages sga_lock=true
-----------------------------------------------
show parameter sga
----------------------------------------------------
prompt Configuracion de parametros performance
-----------------------------------------------
show parameter statistics_level
show parameter timed_statistics
----------------------------------------------------
prompt Configuracion de disk asynch
-----------------------------------------------
show parameter DISK_ASYNCH_IO
----------------------------------------------------
prompt Configuracion filesystemio_options
-----------------------------------------------
show parameter filesystemio_options
----------------------------------------------------
prompt Configuracion de manejo extent tablespace
----------------------------------------------------
select distinct EXTENT_MANAGEMENT from dba_tablespaces;
--------------------------------------------------------
prompt Segment Management AUTO DATA y INDEX tablespace
--------------------------------------------------------
select tablespace_name from dba_tablespaces where SEGMENT_SPACE_MANAGEMENT='MANUAL';
--------------------------------------------------------
prompt Segment Management undo
--------------------------------------------------------
show parameter undo
--------------------------------------------------------
prompt tablas de auditoria
--------------------------------------------------------
select segment_name,tablespacE_name from dba_segments where segment_name in ('AUD$','FGA_LOG$');
--------------------------------------------------------
prompt tareas de mantenimiento
--------------------------------------------------------
col client_name format a50
col operation_name format a50
col ATTRIBUTES format a30
select client_name,operation_name,status from dba_autotask_operation where CLIENT_NAME in ('auto space advisor','sql tuning advisor');
--------------------------------------------------------
prompt retencion de controlfile
--------------------------------------------------------
show parameter control_file_record_keep_time
--------------------------------------------------------
prompt configuracion de FRA
--------------------------------------------------------
show parameter db_reco
--------------------------------------------------------
prompt Jobs en dba_jobs
--------------------------------------------------------
col what format a100
select job,what,SCHEMA_USER from dba_jobs where broken='N' and SCHEMA_USER not in ('SYSMAN','SYS');
--------------------------------------------------------
prompt Objetos creado en tablespaces system,sysaux,USERS
--------------------------------------------------------
set pagesize 200
select owner,segment_name,segment_type,tablespace_name from dba_segments
where owner not in 
('APPQOSSYS',
'CTXSYS',
'DBSNMP',
'DMSYS',
'EXFSYS',
'IBM',
'MDSYS',
'OLAPSYS',
'ORDDATA',
'ORDSYS',
'OUTLN',
'PERFSTAT',
'SCOTT',
'SQLTXPLAIN',
'SYS',
'SYSMAN',
'SYSTEM',
'WMSYS',
'XDB') and
tablespace_name in ('SYSTEM','SYSAUX','USERS');
--------------------------------------------------------
prompt Sesiones y Procesos
--------------------------------------------------------
select * from v$resource_limit where resource_name in ('processes','sessions');
--------------------------------------------------------
prompt objetos en recyclebin
--------------------------------------------------------
select OWNER,TYPE,count(1) Cant
from dba_recyclebin
group by OWNER,TYPE;
--------------------------------------------------------
prompt Fragmentacion
--------------------------------------------------------
set pages 200
set lines 200
col OWNER format a20
col TABLE_NAME format a30
select owner,table_name,round((blocks*8),2)/1024/1024 "size (Gb)" , 
round((num_rows*avg_row_len/1024),2)/1024/1024 "actual_data (Gb)",
(round((blocks*8),2) - round((num_rows*avg_row_len/1024),2))/1024/1024 "wasted_space (Gb)"
from dba_tables
where 
(round((blocks*8),2) > round((num_rows*avg_row_len/1024),2))
and 
table_name in 
(select segment_name from (select owner, segment_name, bytes/1024/1024 meg from dba_segments
where 
segment_type = 'TABLE' 
and
owner != 'SYS' and owner != 'SYSTEM' and owner != 'OLAPSYS' and owner != 'SYSMAN' and owner != 'ODM' and owner != 'RMAN' and owner != 'ORACLE_OCM' and owner != 'EXFSYS' and owner != 'OUTLN' and owner != 'DBSNMP' and owner != 'OPS' and owner != 'DIP' and owner != 'ORDSYS' and owner != 'WMSYS' and owner != 'XDB' and owner != 'CTXSYS' and owner != 'DMSYS' and owner != 'SCOTT' and owner != 'TSMSYS' and owner != 'MDSYS' and owner != 'WKSYS' and owner != 'ORDDATA' and owner != 'OWBSYS' and owner != 'ORDPLUGINS' and owner != 'SI_INFORMTN_SCHEMA' and owner != 'PUBLIC' and owner != 'OWBSYS_AUDIT' and owner != 'APPQOSSYS' and owner != 'APEX_030200' and owner != 'FLOWS_030000' and owner != 'WK_TEST' and owner != 'SWBAPPS' and owner != 'WEBDB' and owner != 'OAS_PUBLIC' and owner != 'FLOWS_FILES' and owner != 'QMS'
order by bytes/1024/1024 desc) 
where rownum <= 20)
order by 5 desc;

select segment_name,segment_type,
sum(round(allocated_space/1024/1024,1)) alloc_mb,
sum(round(used_space/1024/1024,1)) used_mb,
sum(round(reclaimable_space/1024/1024)) reclaim_mb
from table(dbms_space.asa_recommendations())
where segment_type='INDEX'
group by segment_name,segment_type
order by 5 desc;
--------------------------------------------------------
prompt Objetos invalidos /unusable
--------------------------------------------------------
select owner,object_name,object_type,status,last_ddl_time
from dba_objects where status='INVALID';

select owner,index_name,status from dba_indexes where status!='VALID';
--------------------------------------------------------
prompt bloques corruptos
--------------------------------------------------------
SELECT * FROM v$database_block_corruption ORDER BY 1, 3;
--------------------------------------------------------
prompt componentes de BD
--------------------------------------------------------
select comp_name,version,status from dba_registry;
--------------------------------------------------------
prompt objetos en nologgin
--------------------------------------------------------
set pagesize 8000
select owner,table_name,logging from dba_tables where LOGGING='NO' and owner not in ('SYS','SYSTEM','OLAPSYS','SQLTXPLAIN','IBM','MDSYS','ORDDATA','SYSMAN','OLAPSYS','XDB','EXFSYS','WMSYS','DBSNMP');
select owner,index_name,LOGGING from dba_indexes where LOGGING='NO';
--------------------------------------------------------
prompt BD EN FORCE LOGGING
--------------------------------------------------------
select FORCE_LOGGING from v$database;
--------------------------------------------------------
prompt verificacion de status datafiles
--------------------------------------------------------
select file_name,status,tablespace_name from dba_data_files where status!='AVAILABLE';
--------------------------------------------------------
prompt verificacion de parametros2
--------------------------------------------------------
show parameter compatible
show parameter optimizer_mode
show parameter optimizer_features_enable
--------------------------------------------------------
prompt verificacion de cursores
--------------------------------------------------------
SELECT 'session_cached_cursors' parameter,
           lpad(VALUE, 5) VALUE,
           decode(VALUE, 0, '  n/a', to_char(100 * used / VALUE, '9990') || '%') usage
FROM (SELECT MAX(s.VALUE) used
              FROM v$statname n, v$sesstat s
             WHERE n.NAME = 'session cursor cache count'
               AND s.statistic# = n.statistic#),
           (SELECT VALUE FROM v$parameter WHERE NAME = 'session_cached_cursors')
UNION ALL
SELECT 'open_cursors',
           lpad(VALUE, 5),
           to_char(100 * used / VALUE, '9990') || '%'
FROM (SELECT MAX(SUM(s.VALUE)) used
              FROM v$statname n, v$sesstat s
      WHERE n.NAME IN
                   ('opened cursors current', 'session cursor cache count')
      AND s.statistic# = n.statistic#
             GROUP BY s.sid),
     (SELECT VALUE FROM v$parameter WHERE NAME = 'open_cursors');
--------------------------------------------------------
prompt foreign key sin indices
--------------------------------------------------------
SELECT "OWNER",
            "STATUS",
            "TABLE_NAME",
            "FK_NAME",
            "FK_COLUMNS",
            "INDEX_NAME",
            "INDEX_COLUMNS"
       FROM (  SELECT a.owner,
                      CASE
                         WHEN b.table_name IS NULL THEN 'unindexed'
                         ELSE 'indexed'
                      END
                         AS status,
                      a.table_name AS table_name,
                      a.constraint_name AS fk_name,
                      a.fk_columns AS fk_columns,
                      b.index_name AS index_name,
                      b.index_columns AS index_columns
                 FROM (  SELECT a.owner,
                                a.table_name,
                                a.constraint_name,
                                listagg (a.column_name, ',')
                                   WITHIN GROUP (ORDER BY a.position)
                                   fk_columns
                           FROM dba_cons_columns a, dba_constraints b
                          WHERE     a.constraint_name = b.constraint_name
                                AND b.constraint_type = 'R'
                                AND a.owner LIKE 'APP_%'
                                AND a.owner = b.owner
                       GROUP BY a.owner, a.table_name, a.constraint_name) a,
                      (  SELECT index_owner,
                                table_name,
                                index_name,
                                listagg (c.column_name, ',')
                                   WITHIN GROUP (ORDER BY c.column_position)
                                   index_columns
                           FROM dba_ind_columns c
                          WHERE c.index_owner LIKE 'APP_%'
                       GROUP BY index_owner, table_name, index_name) b
                WHERE a.table_name = b.table_name(+)
                      AND b.index_columns(+) LIKE a.fk_columns || '%'
             ORDER BY 1 DESC, 2)
      WHERE status = 'unindexed'
   ORDER BY 1;

-------------------------------------------------------
prompt parametro acceso
--------------------------------------------------------
show parameter O7_DICTIONARY_ACCESSIBILITY
