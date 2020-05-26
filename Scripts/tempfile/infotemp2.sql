--https://www.thegeekdiary.com/how-to-shrink-a-temporary-tablespace-in-oracle-database/

--SPACE MB USED
SELECT   A.tablespace_name tablespace, D.mb_total,
         SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_used,
         D.mb_total - SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_free
FROM     v$sort_segment A,
         (
         SELECT   B.name, C.block_size, SUM (C.bytes) / 1024 / 1024 mb_total
         FROM     v$tablespace B, v$tempfile C
         WHERE    B.ts#= C.ts#
         GROUP BY B.name, C.block_size
         ) D
WHERE    A.tablespace_name = D.name
GROUP by A.tablespace_name, D.mb_total;

TABLESPACE		 MB_TOTAL    MB_USED	MB_FREE
---------------------- ---------- ---------- ----------
TEMP		       84377.9531      11751 72626.9531


 select TABLESPACE_NAME,TABLESPACE_SIZE/1024/1024 "TABLESPACE_SIZE", FREE_SPACE/1024/1024 "FREE_SPACE" from dba_temp_free_space;

TABLESPACE_NAME 	       TABLESPACE_SIZE FREE_SPACE
------------------------------ --------------- ----------
TEMP				    84377.9531	    73787
OBIDOMAIN_IAS_TEMP			    32	       31
APOTEM01				    32	       31
FRSDOMAIN_IAS_TEMP			    32	       31
S90938DOMAIN_IAS_TEMP			    32	       31
S77475DOMAIN_IAS_TEMP			    32	       31
SP1529332966_IAS_TEMP			    32	       31
OBIP_IAS_TEMP				   100	       98
SP1574873318_IAS_TEMP			   100	       99
OFRS_IAS_TEMP				   100	       99
S83614DOMAIN_IAS_TEMP			    32	       31
SP1565714429_IAS_TEMP			    32	       31
S90937DOMAIN_IAS_TEMP			    32	       31
DMG_IAS_TEMP				    32	       31

14 rows selected.


-- RECLAIM SPACE
Below are the queries to Shrink TEMP Tablespace in Oracle:

Shrink TEMP Tablespace using alter tablespace command
SQL> ALTER TABLESPACE temp SHRINK SPACE KEEP 50M;.


Shrink TEMPFILE using alter tablespace command
SQL> ALTER TABLESPACE temp SHRINK TEMPFILE '/u01/app/oracle/oradata/TEST11G/temp01.dbf' KEEP 40M;


Shrink TEMP Tablespace to the smallest possible size:
SQL> ALTER TABLESPACE temp SHRINK SPACE;


---
select FILE_NAME,BYTES/1024/1024/1024 from dba_temp_files;
select FILE_NAME,BYTES/1024/1024/1024,MAXBYTES/1024/1024/1024 from dba_temp_files;

--After resizing tempfiles:
ALTER TABLESPACE TEMP SHRINK TEMPFILE '/scratch/u01/app/oracle/OTMSTG/temp02.dbf' KEEP 1G;



