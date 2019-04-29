alter session set nls_date_format='DD-MON-YYYY hh24:mi:ss';
set echo off
set termout on
set heading on
set feedback off
set trimspool on
set linesize 200
set pagesize 5000
set long 5000
col filename new_value filename
set markup html on spool on
select INSTANCE_NAME filename FROM V$INSTANCE;
Spool '&filename..html'

-----------------------------------------------
prompt Informacion de la Base de Datos
prompt
prompt Estimados: 
prompt Se verifica los siguientes Tablespace superan el umbral de 80% de uso.
-----------------------------------------------
SELECT
  a.tablespace_name,
  ROUND((a.used_space * b.block_size) / 1048576, 2) AS "Espacio Usado (MB)",
  ROUND((a.tablespace_size * b.block_size) / 1048576, 2) AS "Tamaño Tablespace (MB)",
  ROUND(a.used_percent, 2) AS "Uso en %"
FROM dba_tablespace_usage_metrics a
  JOIN dba_tablespaces b 
  ON a.tablespace_name = b.tablespace_name
where (ROUND (a.used_percent, 2) ) > 80;

-----------------------------------------------
prompt
prompt Saludos,
prompt E. Yair Purisaca Rivera
prompt Administrador de Base de Datos
-----------------------------------------------
spool off
exit
