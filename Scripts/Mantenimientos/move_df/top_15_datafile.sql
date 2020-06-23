-- ingresar parametro: nombre filesystem ejemplo /u05
ACCEPT location_fs CHAR PROMPT 'Ingresar ruta para evaluar datafiles >'
SET LINE 300
SET PAGESIZE 30
SET FEEDBACK OFF
SET VERIFY OFF
COLUMN sizedf FORMAT 999,999,999  HEAD 'Size| Datafile GB'
COLUMN namedf FORMAT A25 HEAD 'Name file|Datafile'

break on report on name_file_datafile skip 1
compute sum label "Grand Total: " of sizedf on report

SELECT namedf, sizedf
FROM (
select  substr(name,instr(name,'/',-1)+1) namedf, a.BYTES/1024/1024/1024 as sizedf
from v$datafile a
where a.name like '&location_fs%'
order by 2 desc )
WHERE rownum < 16
/

------------------------------------------------
listdf.sql shell mv_df.sh
SET LINE 300
SET PAGESIZE 30
SET FEEDBACK OFF
SET ECHO OFF
SET VERIFY OFF
SET TRIMSPOOL ON
COLUMN sizedf FORMAT 999,999,999  HEAD 'Size| Datafile GB'
COLUMN namedf FORMAT A25 HEAD 'Name file|Datafile'
spool size_datafile_PRIDWH.log

break on report on name_file_datafile skip 1
compute sum label "Grand Total: " of sizedf on report

SELECT namedf, sizedf
FROM (
select  substr(a.name,instr(a.name,'/',-1)+1) namedf, a.BYTES/1024/1024/1024 as sizedf
from v$datafile a
where a.name like '/&1%'
order by 2 desc )
WHERE rownum < 16
/
