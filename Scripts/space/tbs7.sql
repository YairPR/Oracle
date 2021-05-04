set linesize 200 trimspool on pagesize 50
col tablespace_name format a25
col MB_ALLOC format 99999999.99
col MB_FREE format 99999999.99
col MB_USED format 99999999.99
col "FREE_%" format 99999999.99
col "USED_%" format 99999999.99
col "MAX_MB" format 99999999.99
WITH CONSULTA AS (
select  a.tablespace_name,
       round(a.bytes_alloc / 1024 / 1024 /1024, 2) GB_alloc,
       round(nvl(b.bytes_free, 0) / 1024 / 1024 /1024, 2) GB_free,
       round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024 /1024, 2) GB_used,
       round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) "FREE_%",
       100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) "USED_%",
       round(maxbytes/1024/1024/1024,2) Max_GB
from  ( select  f.tablespace_name,
               sum(f.bytes) bytes_alloc,
               sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
        from dba_data_files f
        group by tablespace_name) a,
      ( select  f.tablespace_name,
               sum(f.bytes)  bytes_free
        from dba_free_space f
        group by tablespace_name) b
where a.tablespace_name = b.tablespace_name (+)
union all
select h.tablespace_name,
       round(sum(h.bytes_free + h.bytes_used) / 1024/1024/1024, 2) GB_alloc,
       round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1024/1024/1024, 2) GB_free,
       round(sum(nvl(p.bytes_used, 0))/ 1024/1024/1024, 2) GB_used,
       round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2) Pct_Free,
       100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2) pct_used,
       round(sum(f.maxbytes) / 1024/1024/1024, 2) max
from   sys.v_$TEMP_SPACE_HEADER h, sys.v_$Temp_extent_pool p, dba_temp_files f
where  p.file_id(+) = h.file_id
and    p.tablespace_name(+) = h.tablespace_name
and    f.file_id = h.file_id
and    f.tablespace_name = h.tablespace_name
group by h.tablespace_name
ORDER BY 6 desc)
select * from CONSULTA
order by 1;

TABLESPACE_NAME             GB_ALLOC    GB_FREE    GB_USED       FREE_%       USED_%     MAX_GB
------------------------- ---------- ---------- ---------- ------------ ------------ ----------
DATA_BDTEST_CTXSYS                .1        .09        .01        93.38         6.62         32
DATA_PROD_MV                      .1         .1          0        99.94          .06         32
DATA_PROD_NOTRANS_BIG        2203.49      64.22    2139.27         2.91        97.09    2207.34
DATA_PROD_NOTRANS_MED         923.66      45.18     878.49         4.89        95.11     919.67
DATA_PROD_SSD_BIG             891.94      18.44      873.5         2.07        97.93        894
DATA_PROD_SSD_MED              51.93      20.79      31.14        40.03        59.97        160
DATA_PROD_TOOLS                35.29      10.04      25.25        28.46        71.54         96
DATA_PROD_TRANS_BIG          2403.19      27.03    2376.16         1.12        98.88    2427.48
DATA_PROD_TRANS_MED           887.88      34.62     853.25         3.90        96.10     887.88
DATA_PROD_TRANS_PAR01           8.78       2.34       6.43        26.70        73.30      96.68
DATA_PROD_TRANS_PAR02           3.22       2.34        .88        72.73        27.27         32


