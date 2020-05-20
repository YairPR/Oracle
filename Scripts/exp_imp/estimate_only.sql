How to Understand and Use ESTIMATE and ESTIMATE_ONLY Parameters in DataPump Export
Posted on March 5, 2016 by james huang
ESTIMATE Parameter
The value for parameter ESTIMATE  is either BLOCKS (default) or STATISTICS.

BLOCKS: The estimated space used is calculated by multiplying the number of database blocks used by the target objects with the appropriate block sizes. It is  the least accurate because of:

The table was created with a much bigger initial extent size than was needed for the actual table data
Many rows have been deleted from the table, or a very small percentage of each block is used.
STATISTICS: The estimated space used is calculated by using statistics for each table. If the table has been recently analyzed, the “estimate=statistics” would be the most accurate.

If a table has LOBs, ESTIMATE dump file size does NOT take LOB size into consideration.

ESTIMATE_ONLY Parameter
Using estimate_only parameter will not generate the dump file other than a logfile .

The value for this parameter is either Y (yes) or N (no = default).

Y: Export estimates the space that would be consumed, but quits without actually performing the export operation.
N: Export does not only estimate, it performs an actual export of data, too.

EXAMPLE :
SQL> select bytes/1024/1024/1024 from dba_segments where owner='JAMES' and segment_name='TEST' and segment_type='TABLE';

BYTES/1024/1024/1024
--------------------
 34.4365234

SQL> desc JAMES.TEST
 Name Null? Type
 ----------------------------------------- -------- ----------------------------
 NAME NOT NULL VARCHAR2(30)
 CREATED NOT NULL DATE
 ......
 ......
 DOC BLOB
 ......
 ......


SQL> select owner,table_name,column_name,segment_name from dba_lobs where owner='JAMES' and table_name='TEST';

OWNER TABLE_NAME
------------------------------ ------------------------------
COLUMN_NAME
--------------------------------------------------------------------------------
SEGMENT_NAME
------------------------------
JAMES TEST
SESSIONITEMLONG
SYS_LOB0000062845C00010$$

SQL> select owner, segment_Name,bytes/1024/1024/1024 from dba_segments where segment_name='SYS_LOB0000062845C00010$$' and owner='JAMES';

OWNER
------------------------------
SEGMENT_NAME
--------------------------------------------------------------------------------
BYTES/1024/1024
---------------
JAMES
SYS_LOB0000062845C00010$$
 38.3


$ expdp \"/ as sysdba\" directory=DATAPUMP_DIR ESTIMATE_ONLY=y ESTIMATE=BLOCKS tables=JAMES.TEST;

....
....
....
Estimate in progress using BLOCKS method...
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. estimated "JAMES"."TEST" 35.50 GB
Total estimation using BLOCKS method: 35.50 GB
Job "SYS"."SYS_EXPORT_TABLE_01" successfully completed at 14:50:11

$expdp \"/ as sysdba\" directory=DATAPUMP_DIR ESTIMATE_ONLY=y ESTIMATE=STATISTICS tables=JAMES.TEST;
......
......
......
Estimate in progress using STATISTICS method...
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. estimated "JAMES"."TEST" 28.96 GB
Total estimation using STATISTICS method: 28.96 GB
Job "SYS"."SYS_EXPORT_TABLE_01" successfully completed at 14:51:31
From the above test, we can see LOB size is not included in estimation size.
