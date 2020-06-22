-- ingresar parametro: nombre filesystem ejemplo /u05
ACCEPT location_fs CHAR PROMPT 'Ingresar ruta para evaluar datafiles >'
set line 300
column name format a100
set pagesize 0
set feedback off
SET VERIFY OFF
spool exe_mv_df.sql
select 'alter database move datafile ' || namefulldf || ' to ' || '''/u02/app/oracle/oradata/PRIDWH/data/' || namedf ||''';'
 from (
select a.name namefulldf, substr(name,instr(name,'/',-1)+1) namedf, a.BYTES/1024/1024/1024 as sizedf
from v$datafile a
where a.name like '&location_fs%'
order by 2 desc )
where rownum < 16
/
spool off
