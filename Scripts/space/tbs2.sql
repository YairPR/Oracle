set linesize 200 trimspool on pagesize 50
col tablespace_name format a25
col MB_ALLOC format 99999999.99
col MB_FREE format 99999999.99
col MB_USED format 99999999.99
col "FREE_%" format 99999999.99
col "USED_%" format 99999999.99
col "MAX_MB" format 99999999.99

select  a.tablespace_name,
       round(a.bytes_alloc / 1024 / 1024, 2) MB_alloc,
       round(nvl(b.bytes_free, 0) / 1024 / 1024, 2) MB_free,
       round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024, 2) MB_used,
       round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) "FREE_%",
       100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) "USED_%",
       round(maxbytes/1048576,2) Max_MB
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
       round(sum(h.bytes_free + h.bytes_used) / 1048576, 2) megs_alloc,
       round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1048576, 2) megs_free,
       round(sum(nvl(p.bytes_used, 0))/ 1048576, 2) megs_used,
       round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2) Pct_Free,
       100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2) pct_used,
       round(sum(f.maxbytes) / 1048576, 2) max
from   sys.v_$TEMP_SPACE_HEADER h, sys.v_$Temp_extent_pool p, dba_temp_files f
where  p.file_id(+) = h.file_id
and    p.tablespace_name(+) = h.tablespace_name
and    f.file_id = h.file_id
and    f.tablespace_name = h.tablespace_name
group by h.tablespace_name
ORDER BY 6 desc;
                                                            
TABLESPACE_NAME               MB_ALLOC      MB_FREE      MB_USED       FREE_%       USED_%       MAX_MB
------------------------- ------------ ------------ ------------ ------------ ------------ ------------
INDX_PROD_TRANS_BIG         4473329.97     39200.00   4434129.97          .88        99.12   4476334.34
INDX_PROD_NOTRANS_BIG       2464089.98     25600.00   2438489.98         1.04        98.96   2468422.13
DATA_PROD_TRANS_BIG         2460870.95     27680.00   2433190.95         1.12        98.88   2485736.06
TBSI_PROD_SMA                856767.72     13868.91    842898.81         1.62        98.38    884527.64
DATA_PROD_SSD_BIG            913347.98     18880.00    894467.98         2.07        97.93    915454.59
TBSD_PROD_LOGMNR             321586.92      8677.63    312909.30         2.70        97.30    372410.88
TBSD_EVENTUAL_NOR           2385123.39     64770.00   2320353.39         2.72        97.28   2385507.20
DATA_PROD_NOTRANS_BIG       2256374.95     65920.00   2190454.95         2.92        97.08   2260311.09
INDX_PROD_TRANS_MED         1833829.63     55820.00   1778009.63         3.04        96.96   1831800.34
TBSD_NORMAL_NOR              694804.98     26160.00    668644.98         3.77        96.23    917503.56
DATA_PROD_TRANS_MED          909184.84     35455.00    873729.84         3.90        96.10    909193.70
TBSD_PROD_SMA                510975.78     21616.41    489359.38         4.23        95.77    524287.75
INDX_PROD_NOTRANS_MED        893320.70     42880.00    850440.70         4.80        95.20    950271.55
DATA_PROD_NOTRANS_MED        945828.84     46270.00    899558.84         4.89        95.11    941739.77
TBSD_OTHERS_BIG              529720.00     38400.00    491320.00         7.25        92.75    885759.58
TBSD_OTHERS_MED              295467.00     29705.00    265762.00        10.05        89.95    393215.81                                                            
                                                            
                                                            
