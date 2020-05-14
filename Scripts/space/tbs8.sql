/*
Tablespace management in an Oracle database is important and something a DBA will need to do quite frequently.  
Therefore I wrote a query, which I believe I originally got from the internet and then it evolved by me adding in
temp tablespace and few other things

AUTO_EXT: If the datafiles are ‘Auto Extendable’ or not.

Please Note: This is using a max function, so if all are ‘NO’, then the ‘NO’ is true for all datafiles, however if one 
is ‘YES’, then the ‘YES’ is possible for one through to all of the datafiles.

MAX_TS_SIZE: This is the maximum Tablespace Size if all the datafile reach their max size.

MAX_TS_PCT_USED: This is the percent of MAX_TS_SIZE reached and is the most important value in the query, as this reflect
s the true usage before DBA intervention is required.

CURR_TS_SIZE: This is the current size of the Tablespace.

USED_TS_SIZE: This is how much of the CURR_TS_SIZE is used.

TS_PCT_USED: This is the percent of CURR_TS_SIZE which if ‘Auto Extendable’ is on, is a little meaningless. 
Use MAX_TS_PCT_USED for actual usage.

FREE_TS_SIZE: This is how much is free in CURR_TS_SIZE.

TS_PCT_FREE: This is how much is free in CURR_TS_SIZE as a percent.

Please Note: All sizes are in Megabytes, this can be changed to Gigabytes by added a ‘/1024’ to the columns.


*/

set pages 999
set lines 400
SELECT df.tablespace_name tablespace_name,
 max(df.autoextensible) auto_ext,
 round(df.maxbytes / (1024 * 1024), 2) max_ts_size,
 round((df.bytes - sum(fs.bytes)) / (df.maxbytes) * 100, 2) max_ts_pct_used,
 round(df.bytes / (1024 * 1024), 2) curr_ts_size,
 round((df.bytes - sum(fs.bytes)) / (1024 * 1024), 2) used_ts_size,
 round((df.bytes-sum(fs.bytes)) * 100 / df.bytes, 2) ts_pct_used,
 round(sum(fs.bytes) / (1024 * 1024), 2) free_ts_size,
 nvl(round(sum(fs.bytes) * 100 / df.bytes), 2) ts_pct_free
FROM dba_free_space fs,
 (select tablespace_name,
 sum(bytes) bytes,
 sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes,
 max(autoextensible) autoextensible
 from dba_data_files
 group by tablespace_name) df
WHERE fs.tablespace_name (+) = df.tablespace_name
GROUP BY df.tablespace_name, df.bytes, df.maxbytes
UNION ALL
SELECT df.tablespace_name tablespace_name,
 max(df.autoextensible) auto_ext,
 round(df.maxbytes / (1024 * 1024), 2) max_ts_size,
 round((df.bytes - sum(fs.bytes)) / (df.maxbytes) * 100, 2) max_ts_pct_used,
 round(df.bytes / (1024 * 1024), 2) curr_ts_size,
 round((df.bytes - sum(fs.bytes)) / (1024 * 1024), 2) used_ts_size,
 round((df.bytes-sum(fs.bytes)) * 100 / df.bytes, 2) ts_pct_used,
 round(sum(fs.bytes) / (1024 * 1024), 2) free_ts_size,
 nvl(round(sum(fs.bytes) * 100 / df.bytes), 2) ts_pct_free
FROM (select tablespace_name, bytes_used bytes
 from V$temp_space_header
 group by tablespace_name, bytes_free, bytes_used) fs,
 (select tablespace_name,
 sum(bytes) bytes,
 sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes,
 max(autoextensible) autoextensible
 from dba_temp_files
 group by tablespace_name) df
WHERE fs.tablespace_name (+) = df.tablespace_name
GROUP BY df.tablespace_name, df.bytes, df.maxbytes
ORDER BY 4 DESC;
