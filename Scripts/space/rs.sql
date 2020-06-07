SET LINESIZE 500

COLUMN RESIZE FORMAT A120
COLUMN ADD_FILE FORMAT A90

with consulta as (
SELECT   file_id, tablespace_name,
                  FILE_NAME,
                  ROUND (SUM (bytes) / (1024 * 1024 * 1024), 2) TotalSpace,
                  ROUND (SUM (bytes) / (1024 * 1024), 2) TotalSpace_MB
             FROM dba_data_files
             where file_id=&1
             group by file_id,tablespace_name,file_name)
             select 
             ' ALTER DATABASE DATAFILE '
         || ''''
         || FILE_NAME
         || ''''
         || ' RESIZE '
         || (&2) * 1024
         || 'M;'
            RESIZE,
            ' ALTER TABLESPACE '
         || TABLESPACE_NAME
         || ' ADD DATAFILE '
         || ' SIZE '
         || (&2) * 1024
         || 'M AUTOEXTEND OFF;'
            ADD_FILE
            from consulta
/
