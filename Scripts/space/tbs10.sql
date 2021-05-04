WITH my_ddf AS
    (
        SELECT file_id, tablespace_name, file_name,
               DECODE (autoextensible,
                       'YES', GREATEST (BYTES, maxbytes),
                       BYTES
                      ) mysize,
              DECODE (autoextensible,
                      'YES', CASE
                         WHEN (maxbytes > BYTES)
                            THEN (maxbytes - BYTES)
                         ELSE 0
                      END,
                      0
                     ) growth
         FROM dba_data_files)
SELECT   my_ddf.tablespace_name,
         ROUND (SUM (my_ddf.mysize) / (1024 * 1024)) totsize,
         ROUND (SUM (growth) / (1024 * 1024)) growth,
         ROUND ((SUM (NVL (freebytes, 0))) / (1024 * 1024)) dfs,
         ROUND ((SUM (NVL (freebytes, 0)) + SUM (growth)) / (1024 * 1024)
               ) totfree,
         ROUND (  (SUM (NVL (freebytes, 0)) + SUM (growth))
                 / SUM (my_ddf.mysize)
                 * 100
               ) perc
    FROM my_ddf, (SELECT   file_id, SUM (BYTES) freebytes
                      FROM dba_free_space
                  GROUP BY file_id) dfs
   WHERE my_ddf.file_id = dfs.file_id(+)
         AND my_ddf.tablespace_name NOT LIKE '%UNDOTB%'
GROUP BY my_ddf.tablespace_name
ORDER BY 6 DESC;

TABLESPACE_NAME                   TOTSIZE     GROWTH        DFS    TOTFREE       PERC
------------------------------ ---------- ---------- ---------- ---------- ----------
TBS_OGG                             32768      31368       1307      32675        100
DATA_PROD_MV                        32768      32668        100      32768        100
USERS                              196608     196553         45     196598        100
DATA_BDTEST_CTXSYS                  32768      32668         93      32761        100
TBSI_QUEST                          32768      32368         86      32454         99
INDX_PROD_TRANS_PAR02               65536      63812       1120      64932         99
TBSD_QUEST                          32768      32268         97      32365         99
INDX_PROD_SSD_MED                  163840     156296       6235     162531         99
INDX_PROD_TRANS_PAR03               65536      63212       1120      64332         98
DATA_PROD_TRANS_PAR03               65536      52436      12000      64436         98
XDB                                 65536      63312       1125      64437         98
DATA_PROD_TRANS_PAR02               32768      29468       2400      31868         97
TBSD_CRITI_BIG                     196608     188460       2370     190830         97
TBSI_WEB_BIG                       393216     362516       5760     368276         94
DATA_PROD_TRANS_PAR01               99004      90016       2400      92416         93
TBSD_NORMA_TMP                     589824     510678      21080     531758         90
TBSI_WEB_MED                       131072     113383       3445     116828         89
TBSD_WEB_SMA                       262144     222276      11535     233811         89
SYSTEM                              98304      80784       6885      87669         89
TBSI_WEB_SMA                       196608     165429       6003     171432         87
TBSD_WEB_BIG                       393216     312061      21120     333181         85
TBSI_OTHERS_SMA                    163840     132996       5382     138378         84

