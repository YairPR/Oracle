-- -----------------------------------------------------------------------------------
-- File Name    : https://oracle-base.com/dba/monitoring/free_space.sql
-- Author       : Tim Hall
-- Description  : Displays space usage for each datafile.
-- Requirements : Access to the DBA views.
-- Call Syntax  : @free_space ----> Ingresar nombre tablespace
-- Last Modified: 15-JUL-2000 - Created.
--                12-OCT-2012 - Amended to include auto-extend and maxsize.
--                04/05/2021  - EYPR
-- Lleno mas de 30% muestra "XXX" - Vacio muestra "------"
-- -----------------------------------------------------------------------------------
SET PAGESIZE 100
SET LINESIZE 265

COLUMN tablespace_name FORMAT A20
COLUMN file_name FORMAT A50

SELECT df.tablespace_name,
       df.file_name,
       df.size_mb,
       f.free_mb,
       df.max_size_mb,
       f.free_mb + (df.max_size_mb - df.size_mb) AS max_free_mb,
       RPAD(' '|| RPAD('X',ROUND((df.max_size_mb-(f.free_mb + (df.max_size_mb - df.size_mb)))/max_size_mb*10,0), 'X'),11,'-') AS used_pct
FROM   (SELECT file_id,
               file_name,
               tablespace_name,
               TRUNC(bytes/1024/1024) AS size_mb,
               TRUNC(GREATEST(bytes,maxbytes)/1024/1024) AS max_size_mb
        FROM   dba_data_files) df,
       (SELECT TRUNC(SUM(bytes)/1024/1024) AS free_mb,
               file_id
        FROM dba_free_space
        GROUP BY file_id) f
WHERE  df.file_id = f.file_id (+)
            and df.tablespace_name ='&tbs_name'
ORDER BY df.tablespace_name,
         df.file_name;

PROMPT
SET PAGESIZE 14
            
TABLESPACE_NAME      FILE_NAME                                             SIZE_MB    FREE_MB MAX_SIZE_MB MAX_FREE_MB USED_PCT
-------------------- -------------------------------------------------- ---------- ---------- ----------- ----------- -----------
INDX_PROD_SSD_MED    +DG_DATA/prod/datafile/indx_prod_ssd_med.1059.1037        700         30       32767       32097  ----------
                     176311

INDX_PROD_SSD_MED    +DG_DATA/prod/datafile/indx_prod_ssd_med.1062.1037        700         70       32767       32137  ----------
                     176319

INDX_PROD_SSD_MED    +DG_DATA/prod/datafile/indx_prod_ssd_med.1246.1067       2048       2045       32767       32764  ----------
                     215895

INDX_PROD_SSD_MED    +DG_DATA/prod/datafile/indx_prod_ssd_med.1247.1067       2048       2045       32767       32764  ----------
                     215911

