SET LINESIZE 500
COLUMN TABLESPACE_NAME        HEADING 'TABLESPACE | NAME'
COLUMN FILE_NAME           HEADING 'FILE | NAME'
COLUMN TABLESPACE_NAME FORMAT A20
COLUMN FILE_NAME FORMAT A50
COLUMN RESIZE FORMAT A30
COLUMN ADD_FILE FORMAT A30
WITH TS AS (SELECT UPPER ('&TABLESPACE') TS_NAME FROM DUAL),
     TOTAL_SPACE
     AS (  SELECT file_id,
                  tablespace_name,
                  FILE_NAME,
                  ROUND (SUM (bytes) / (1024 * 1024 * 1024), 2) TotalSpace,
                  ROUND (SUM (bytes) / (1024 * 1024), 2) TotalSpace_MB
             FROM dba_data_files A JOIN TS B ON A.TABLESPACE_NAME = B.TS_NAME
         GROUP BY tablespace_name, FILE_NAME, file_id),
     REPORTE
     AS (SELECT df.tablespace_name ,
                totalusedspace USED_GB,
                round((df.totalspace - tu.totalusedspace),2) Free_GB,
                df.totalspace Total_GB,
                ROUND (
                   100
                   * ( (df.totalspace - tu.totalusedspace) / df.totalspace))
                   Pct_Free
           FROM (  SELECT tablespace_name,
                          ROUND (SUM (bytes) / (1024 * 1024 * 1024),2) TotalSpace
                     FROM dba_data_files
                 GROUP BY tablespace_name) df,
                (  SELECT ROUND (SUM (bytes) / (1024 * 1024 * 1024),2) totalusedspace,
                          tablespace_name
                     FROM dba_segments
                 GROUP BY tablespace_name) tu
          WHERE df.tablespace_name = tu.tablespace_name
          and df.tablespace_name = (select TS_NAME from TS))
  SELECT A.tablespace_name,
         Total_GB,
         Free_GB,
         TotalSpace FILE_GB,
         file_name,
         '@rs '||A.file_id ||' '|| (TotalSpace+1) resize,
         '@tbsff_shrink '||A.file_id shrink
    FROM TOTAL_SPACE A left join REPORTE B on A.tablespace_name = B.tablespace_name
--where savings >= 1
ORDER BY TotalSpace desc, A.tablespace_name, file_name
/
                                    
                                    TABLESPACE                                            FILE
 NAME                  TOTAL_GB    FREE_GB    FILE_GB  NAME                                              RESIZE                         SHRINK
-------------------- ---------- ---------- ---------- -------------------------------------------------- ------------------------------ ------------------------------------------------------
INDX_PROD_TRANS_BIG     4368.49      46.77         32 +DG_DATA/prod/datafile/indx_prod_trans_big.1291.10 @rs 1015 33                    @tbsff_shrink 1015
                                                      67248509

INDX_PROD_TRANS_BIG     4368.49      46.77         32 +DG_DATA/prod/datafile/indx_prod_trans_big.1314.10 @rs 1038 33                    @tbsff_shrink 1038
                                                      70464619

INDX_PROD_TRANS_BIG     4368.49      46.77         32 +DG_DATA/prod/datafile/indx_prod_trans_big.1315.10 @rs 1039 33                    @tbsff_shrink 1039
                                                      70464663

INDX_PROD_TRANS_BIG     4368.49      46.77         32 +DG_DATA/prod/datafile/indx_prod_trans_big.714.103 @rs 686 33                     @tbsff_shrink 686
                                                      7154165

INDX_PROD_TRANS_BIG     4368.49      46.77         32 +DG_DATA/prod/datafile/indx_prod_trans_big.722.103 @rs 753 33                     @tbsff_shrink 753


