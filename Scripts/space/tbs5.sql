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
