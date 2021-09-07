PCT_FREE

-- Check from the DBA_TABLES or USER_TABLES

select a.owner, a.table_name, a.tablespace_name, a.status, a.pct_free, a.num_rows, a.last_analyzed 
from dba_tables a 
where  a.table_name in ('NUEVO_CUENTA_INDIVIDUAL2_COPIA', 'NUEVO_CUENTA_INDIVIDUAL3_COPIA', 'ACREDITACIONES_COPIA1', 'ACREDITACIONES_COPIA2',
'NUEVO_ASEGURADOS_COPIA1', 'NUEVO_ASEGURADOS_COPIA2' )
union all
select a.owner, a.index_name, a.tablespace_name, a.status, a.pct_free, a.num_rows, a.last_analyzed
from dba_indexes a
where a.index_name IN  ('PK_NCTAIND_COPIA2', 'IDX_NCTAIND_01_COPIA2', 'IDX_NCTAIND_02_COPIA2', 'IDX_NCTAIND_03_COPIA2', 'PK_NCTAIND_COPIA3', 
'IDX_NCTAIND_01_COPIA3', 'IDX_NCTAIND_02_COPIA3', 'IDX_NCTAIND_03_COPIA3', 'PK_ACREDITA2_COPIA1', 'PK_ACREDITA2_COPIA2','IDX_NASEG_01_COPIA',
'IDX_NASEG_04_COPIA','IDX_NUEVO_ASEGURADOS_01_COPIA','IDX_NASEG_02_COPIA','IDX_NASEG_03_COPIA'
)
/



set line 1000
col "Schema" for a30
col "Object Name" for a30
col "Object Type" for a20
select
owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024,2) as "Object Size (Mb)"
, tablespace_name as "Tablespace"
from dba_segments
where segment_name in ('PK_NCTAIND_COPIA2', 'IDX_NCTAIND_01_COPIA2', 'IDX_NCTAIND_02_COPIA2', 'IDX_NCTAIND_03_COPIA2', 'PK_NCTAIND_COPIA3', 
'IDX_NCTAIND_01_COPIA3', 'IDX_NCTAIND_02_COPIA3', 'IDX_NCTAIND_03_COPIA3', 'PK_ACREDITA2_COPIA1', 'PK_ACREDITA2_COPIA2','IDX_NASEG_01_COPIA',
'IDX_NASEG_04_COPIA','IDX_NUEVO_ASEGURADOS_01_COPIA','IDX_NASEG_02_COPIA','IDX_NASEG_03_COPIA', 'NUEVO_CUENTA_INDIVIDUAL2_COPIA', 'NUEVO_CUENTA_INDIVIDUAL3_COPIA', 'ACREDITACIONES_COPIA1', 'ACREDITACIONES_COPIA2',
'NUEVO_ASEGURADOS_COPIA1', 'NUEVO_ASEGURADOS_COPIA2')
order by 4 desc
/

select owner, segment_name, sum(bytes)/1024/1024 from dba_segments where segment_name in ( 'NUEVO_CUENTA_INDIVIDUAL2_COPIA', 'NUEVO_CUENTA_INDIVIDUAL3_COPIA', 'ACREDITACIONES_COPIA1',
                                                                                            'ACREDITACIONES_COPIA2', 'PK_NCTAIND_COPIA2', 'IDX_NCTAIND_01_COPIA2', 'IDX_NCTAIND_02_COPIA2', 'IDX_NCTAIND_03_COPIA2', 'PK_NCTAIND_COPIA3', 'IDX_NCTAIND_01_COPIA3', 'IDX_NCTAIND_02_COPIA3', 'IDX_NCTAIND_03_COPIA3', 'PK_ACREDITA2_COPIA1', 'PK_ACREDITA2_COPIA2')
 group by  sum(bytes)/1024/1024 
 select owner, object_name, LAST_DDL_TIME from dba_objects where object_name in  ('
