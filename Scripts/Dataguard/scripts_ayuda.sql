********************************************************************************************************
*  SCRIPTS DE AYUDA DATAGUARD                  
********************************************************************************************************
--> EN CONTINGENCIA

-- Busca los log aplicados en el ultimo día
set line 1000
SELECT SEQUENCE#, 
       to_char(FIRST_TIME,'hh24:mi:ss dd/mm/yyyy'), 
       to_char(NEXT_TIME,'hh24:mi:ss dd/mm/yyyy'),
       APPLIED 
 FROM V$ARCHIVED_LOG 
 where next_time>sysdate-1 
 ORDER BY SEQUENCE# ;

-- Ultima secuencia aplicada uso: primario/secundario
SELECT to_char(max(FIRST_TIME),
       'hh24:mi:ss dd/mm/yyyy') 
FROM V$ARCHIVED_LOG 
WHERE applied='YES';
 
-- ¿Que esta haciendo los procesos background de Dataguard?
  SELECT PROCESS, STATUS, THREAD#, SEQUENCE#, BLOCK#, BLOCKS 
  FROM V$MANAGED_STANDBY;
  
  select distinct process, status, thread#, sequence#, block#, blocks from v$managed_standby ;
 
-- ¿Estamod en Producción o en Contingencia?
 SELECT DATABASE_ROLE, DB_UNIQUE_NAME INSTANCE, OPEN_MODE, PROTECTION_MODE, PROTECTION_LEVEL, SWITCHOVER_STATUS 
 FROM V$DATABASE;
 
-- Revisar ERRORES
 SELECT MESSAGE FROM V$DATAGUARD_STATUS;
 
 errore ulitmas 6 horas
 set pagesize 2000
set lines 2000
col MESSAGE for a90
select message,timestamp from V$DATAGUARD_STATUS where timestamp > sysdate - 1/6;
 
-- Check that the DB was openned correctly 
 SELECT RECOVERY_MODE FROM V$ARCHIVE_DEST_STATUS;

-- stadisticas lag importantes
 select * from v$dataguard_stats;
 
 -- Muestra la diferencia entre recibido y aplicado
                                                                             
SELECT ARCH.THREAD# "Thread", ARCH.SEQUENCE# "Last Sequence Received", APPL.SEQUENCE# "Last Sequence Applied", (ARCH.SEQUENCE# - APPL.SEQUENCE#) "Difference"
FROM (SELECT THREAD# ,SEQUENCE# FROM V$ARCHIVED_LOG WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$ARCHIVED_LOG GROUP BY THREAD#)) ARCH,
(SELECT THREAD# ,SEQUENCE# FROM V$LOG_HISTORY WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$LOG_HISTORY GROUP BY THREAD#)) APPL
WHERE ARCH.THREAD# = APPL.THREAD#;
                                       

-- iniciar y detener la sincronización en Dataguard
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE disconnect; (?)

Bajar:
alter database recover managed standby database cancel;

Activar
alter database recover managed standby database disconnect from session;

Verificar
select process,status,thread#,sequence# from v$managed_standby;


-- Registrar manualmente archivelog
alter database register physical logfile '<fullpath/filename>';

-- Compruebe si los registros en espera están configurados correctamente

set lines 100 pages 999
col member format a70
SELECT	st.group#,
       st.sequence#,
       ceil(st.bytes / 1048576) mb,
       lf.member
FROM	v$standby_log	st,	v$logfile	lf
WHERE	st.group# = lf.group#
/

- Si usa real time apply
select recovery_mode from v$archive_dest_status where dest_id=1;
select TYPE, ITEM, to_char(TIMESTAMP, 'DD-MON-YYYY HH24:MI:SS') from v$recovery_progress where ITEM='Last Applied Redo';

-- EN PRIMARIO
 -- configurar envío de archuvelog en primario
alter system set log_archive_dest_3='SERVICE=DEVPCOMB LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES, PRIMARY_ROLE) DB_UNIQUE_NAME=DEVPCOMB';
alter system set log_archive_dest_state_3='enable';
