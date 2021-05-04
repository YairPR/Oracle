set linesize 100
set pagesize 100
col file_name for a60
 
select
    a.tablespace_name,
    round(SUM(a.bytes)/(1024*1024)) CURRENT_MB,
    round(SUM(decode(a.AUTOEXTENSIBLE, 'NO', A.BYTES/(1024*1024), GREATEST (a.MAXBYTES/(1024*1024),A.BYTES/(1024*1024))))) MAX_MB,
    round((SUM(a.bytes)/(1024*1024) - c.Free/1024/1024)) USED_MB,
    round((SUM(decode(a.AUTOEXTENSIBLE, 'NO', A.BYTES/(1024*1024), GREATEST (a.MAXBYTES/(1024*1024),A.BYTES/(1024*1024)))) - (SUM(a.bytes)/(1024*1024) - round(c.Free/1024/1024))),2) FREE_MB,
    round(100*(SUM(a.bytes)/(1024*1024) - round(c.Free/1024/1024))/(SUM(decode(a.AUTOEXTENSIBLE, 'NO', A.BYTES/(1024*1024),GREATEST (a.MAXBYTES/(1024*1024),A.BYTES/(1024*1024)))))) USED_PCT
from
    dba_data_files a,
    (
        SELECT
            d.tablespace_name ,sum(nvl(c.bytes,0)) Free
        FROM
            dba_tablespaces d,
            DBA_FREE_SPACE c
        WHERE
            d.tablespace_name = c.tablespace_name(+)
            --AND d.contents='PERMANENT'
            --AND d.status='ONLINE'
            group by d.tablespace_name
    ) c
WHERE
    a.tablespace_name = c.tablespace_name
GROUP BY a.tablespace_name, c.Free/1024
order by 6;

TABLESPACE_NAME      CURRENT_MB       MAX_MB    USED_MB    FREE_MB   USED_PCT
-------------------- ---------- ------------ ---------- ---------- ----------
DATA_BDTEST_CTXSYS          100     32768.00          7   32760.98          0
TBS_OGG                    1400     32768.00         93   32674.98          0
USERS                        55    196608.00         10  196597.91          0
DATA_PROD_MV                100     32768.00          0   32767.98          0
TBSI_QUEST                  400     32768.00        314   32453.98          1
TBSD_QUEST                  500     32768.00        403   32364.98          1
INDX_PROD_SSD_MED          7544    163840.00       1309  162530.92          1
INDX_PROD_TRANS_PAR0       1724     65536.00        604   64931.97          1
