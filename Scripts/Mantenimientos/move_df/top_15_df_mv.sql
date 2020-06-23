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
order by 3 desc )
where rownum < 16
/
spool off

--------------------------------
--lista_dbf.sql in mv_df.sh

set line 300
column name format a100
set pagesize 0
set feedback off
SET VERIFY OFF
set trimspool on
------column dcol new_value SYSDATE noprint
-------select to_char(sysdate,'YYYYMMDD') dcol from dual;
spool exe_mv_df.sql
select'alter database move datafile '||'''' || namefulldf || '''' || ' to ' || '''/u02/app/oracle/oradata/PRIDWH/data/' || namedf ||''';'
 from ( SELECT a.name namefulldf, substr(a.name,instr(a.name,'/',-1)+1) namedf, a.BYTES/1024/1024/1024 as sizedf
        FROM v$datafile a
        WHERE a.name like '/&1%'
        ORDER BY 3 desc )
where rownum < 16
/
spool off;

