PCT_FREE

-- Check from the DBA_TABLES or USER_TABLES

select a.owner, a.table_name, a.tablespace_name, a.status, a.pct_free, a.num_rows, a.last_analyzed ,sum(b.bytes)/1024/1024
from dba_tables a, dba_segments b 
where a.table_name = b.segment_name
and a.table_name in ('NUEVO_CUENTA_INDIVIDUAL2_COPIA', 'NUEVO_CUENTA_INDIVIDUAL3_COPIA', 'ACREDITACIONES_COPIA1', 'ACREDITACIONES_COPIA2')
group by 

union all
select a.owner, a.index_name, a.tablespace_name, a.status, a.pct_free, a.num_rows, a.last_analyzed,sum(b.bytes)/1024/1024
from dba_indexes a, dba_segments b
where a.index_name = b.segment_name
and index_name IN  ('PK_NCTAIND_COPIA2', 'IDX_NCTAIND_01_COPIA2', 'IDX_NCTAIND_02_COPIA2', 'IDX_NCTAIND_03_COPIA2', 'PK_NCTAIND_COPIA3', 'IDX_NCTAIND_01_COPIA3', 'IDX_NCTAIND_02_COPIA3', 'IDX_NCTAIND_03_COPIA3', 'PK_ACREDITA2_COPIA1', 'PK_ACREDITA2_COPIA2')
/


select owner, segment_name, sum(bytes)/1024/1024 from dba_segments where segment_name in ( 'NUEVO_CUENTA_INDIVIDUAL2_COPIA', 'NUEVO_CUENTA_INDIVIDUAL3_COPIA', 'ACREDITACIONES_COPIA1',
                                                                                            'ACREDITACIONES_COPIA2', 'PK_NCTAIND_COPIA2', 'IDX_NCTAIND_01_COPIA2', 'IDX_NCTAIND_02_COPIA2', 'IDX_NCTAIND_03_COPIA2', 'PK_NCTAIND_COPIA3', 'IDX_NCTAIND_01_COPIA3', 'IDX_NCTAIND_02_COPIA3', 'IDX_NCTAIND_03_COPIA3', 'PK_ACREDITA2_COPIA1', 'PK_ACREDITA2_COPIA2')
 group by  sum(bytes)/1024/1024 
 select owner, object_name, LAST_DDL_TIME from dba_objects where object_name in  ('
