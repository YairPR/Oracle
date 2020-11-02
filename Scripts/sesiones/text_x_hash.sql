--- sql text por hash

accept addr prompt 'Hash do Comando => ';
def hash=&&1
col hv		noprint
col ln		heading 'Line'                  format        9,999
col text	heading 'SQL Statement Text'    format          A65
start osmtitle
select  t.hash_value hv,
        t.piece ln,
        t.sql_text text
from    v$sqlarea a,
        v$sqltext t
where   a.hash_value = t.hash_value
  and   a.hash_value = '&hash'
order by 1,2
/


  Line SQL Statement Text
------ -----------------------------------------------------------------
     0 DELETE GEN_DATA_TEMP WHERE FECDEPURA < SYSDATE OR FECDEPURA IS N
     1 ULL
