-- Validación del restore de datfiles muestra el SCN  por fecha

alter session set nls_date_format='DD-MON-YYYY hh24:mi:ss';
set line 300
set pagesize 100
col df# for 99999
col df_name for a100
col Tablespace_name for a25
col STATUS for a8
col ERROR for a15
col CHANGE# for 9999999999999999
col TIME for 9999999999999999
SELECT r.FILE# AS df#, d.NAME AS df_name, t.NAME AS Tablespace_name,
d.STATUS, r.ERROR, r.CHANGE#, r.TIME
FROM V$RECOVER_FILE r, V$DATAFILE d, V$TABLESPACE t
WHERE t.TS# = d.TS#
AND d.FILE# = r.FILE#;


Exportar data desde una DB read only

Guiarse del link

https://dbaclass.com/article/use-expdp-export-data-physical-standby-database/

http://dbaharrison.blogspot.com/2014/09/datapump-export-from-standbyread-only.html
