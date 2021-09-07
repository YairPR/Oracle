PCT_FREE

-- Check from the DBA_TABLES or USER_TABLES

select owner, table_name, tablespace_name, status, pct_free, num_rows, last_analyzed from dba_tables where table_name in ('NUEVO_CUENTA_INDIVIDUAL2_COPIA', 'NUEVO_CUENTA_INDIVIDUAL3_COPIA', 'ACREDITACIONES_COPIA1', 'ACREDITACIONES_COPIA2')
union all
select owner, index_name, tablespace_name, status, pct_free, num_rows, last_analyzed from dba_indexes where index_name IN  ('PK_NCTAIND_COPIA2', 'IDX_NCTAIND_01_COPIA2', 'IDX_NCTAIND_02_COPIA2', 'IDX_NCTAIND_03_COPIA2', 'PK_NCTAIND_COPIA3', 'IDX_NCTAIND_01_COPIA3', 'IDX_NCTAIND_02_COPIA3', 'IDX_NCTAIND_03_COPIA3', 'PK_ACREDITA2_COPIA1', 'PK_ACREDITA2_COPIA2');

