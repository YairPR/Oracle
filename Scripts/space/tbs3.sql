--- Evalua por tablespace

select x.tablespace_name,
       y.EXTENT_MANAGEMENT,
       y.ALLOCATION_TYPE,
       y.NEXT_EXTENT/1024/1024 next_extentMb,
       x.sizemb,
       x.freemb,
       x.porfree
from
(
select x.tablespace_name,
       round((sum(x.bytes)/1024)/1024,2) SizeMB,
       y.freeMb,
       round( (y.freemb/
             (
               (sum(x.bytes)/1024)/1024
             ))*100,2) porFree
from dba_data_files x,
 (
   select tablespace_name,
          round((sum(bytes)/1024)/1024,2) FreeMB
   from  dba_free_space
   group by tablespace_name
 ) y
where y.tablespace_name = x.tablespace_name and
      x.tablespace_name = nvl(upper('&&tbsp'), x.tablespace_name)
group by x.tablespace_name,
         y.freemb
union
select x.tablespace_name,
       round((sum(x.bytes)/1024)/1024,2) SizeMB,
       0,
       0
from dba_data_files x
where not exists
 (
   select 1
   from  dba_free_space y
   where y.tablespace_name = x.tablespace_name
 ) and
 x.tablespace_name = nvl(upper('&&tbsp'), x.tablespace_name)
group by x.tablespace_name
union
select tablespace_name,
       sum(bytes_used+bytes_free)/1024/1024,
       sum(bytes_free)/1024/1024,
       (sum(bytes_free)/sum(bytes_used+bytes_free))*100
from V$TEMP_SPACE_HEADER
where tablespace_name = nvl(upper('&&tbsp'), tablespace_name)
group by tablespace_name
) x,
 dba_tablespaces y
where y.tablespace_name = x.tablespace_name
order by 1
/

        
        TABLESPACE_NAME           EXTENT_MAN ALLOCATIO NEXT_EXTENTMB     SIZEMB     FREEMB    PORFREE
------------------------- ---------- --------- ------------- ---------- ---------- ----------
INDX_PROD_TRANS_BIG       LOCAL      UNIFORM             160 4473329.97      39200        .88

1 row selected.

