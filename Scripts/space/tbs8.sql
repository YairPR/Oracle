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
     
TABLESPACE_NAME           AUT MAX_TS_SIZE MAX_TS_PCT_USED CURR_TS_SIZE USED_TS_SIZE TS_PCT_USED FREE_TS_SIZE TS_PCT_FREE
------------------------- --- ----------- --------------- ------------ ------------ ----------- ------------ -----------
INDX_PROD_TRANS_BIG       YES  4476334.34           99.06   4473329.97   4434129.97       99.12        39200           1
INDX_PROD_NOTRANS_BIG     YES  2468422.13           98.79   2464089.98   2438649.98       98.97        25440           1
DATA_PROD_TRANS_BIG       YES  2485736.06           97.89   2460870.95   2433190.95       98.88        27680           1
DATA_PROD_SSD_BIG         YES   915454.59           97.71    913347.98    894467.98       97.93        18880           2
TBSD_EVENTUAL_NOR         YES   2385507.2           97.27   2385123.39   2320353.39       97.28        64770           3
INDX_PROD_TRANS_MED       YES  1831800.34           97.06   1833829.63   1778034.63       96.96        55795           3
DATA_PROD_NOTRANS_BIG     YES  2260311.09           96.92   2256374.95   2190614.95       97.09        65760           3
DATA_PROD_TRANS_MED       YES    909193.7            96.1    909184.84    873729.84        96.1        35455           4
DATA_PROD_NOTRANS_MED     YES   941739.77           95.52    945828.84    899578.84       95.11        46250           5
TBSI_PROD_SMA             YES   884527.64           95.29    856767.72    842899.28       98.38     13868.44           2
TBSD_PROD_SMA             YES   524287.75           93.34    510975.78    489359.38       95.77     21616.41           4
INDX_PROD_NOTRANS_MED     YES   950271.55            89.5     893320.7     850455.7        95.2        42865           5
TBSD_PROD_LOGMNR          YES   372410.88           84.02    321586.92     312909.3        97.3      8677.63           3
TEMP_PROD_NOTRANS_BIG     YES   229369.98           80.15       217082       183835       84.68        33247          15
UNDOTBS2                  NO       360437           77.65       360437       279893       77.65        80544          22
TBSD_PROD_MED             YES   458751.78           76.04    393127.97    348812.97       88.73        44315          11
TBSD_MCRITICO_ESP         YES  1115135.47           74.38       926853       829413       89.49        97440          11

