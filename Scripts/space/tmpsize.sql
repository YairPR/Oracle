--
-- Temporary Tablespace Usage.
--
SET PAUSE ON
SET PAUSE 'Press Return to Continue'
SET PAGESIZE 60
SET LINESIZE 300
 
COL TABLESPACE_SIZE FOR 999,999,999,999
COL ALLOCATED_SPACE FOR 999,999,999,999
COL FREE_SPACE FOR 999,999,999,999
 
SELECT *
FROM   dba_temp_free_space
/


--
-- Temporary Tablespace Sort Usage.
--
 
SET PAUSE ON
SET PAUSE 'Press Return to Continue'
SET PAGESIZE 60
SET LINESIZE 300
 
SELECT 
   A.tablespace_name tablespace, 
   D.mb_total,
   SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_used,
   D.mb_total - SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_free
FROM 
   v$sort_segment A,
(
SELECT 
   B.name, 
   C.block_size, 
   SUM (C.bytes) / 1024 / 1024 mb_total
FROM 
   v$tablespace B, 
   v$tempfile C
WHERE 
   B.ts#= C.ts#
GROUP BY 
   B.name, 
   C.block_size
) D
WHERE 
   A.tablespace_name = D.name
GROUP by 
   A.tablespace_name, 
   D.mb_total
/


Query to see Current Temp Datafiles State
To see the current state of the temp datafiles:

set pages 999
set lines 400
col FILE_NAME format a75
select d.TABLESPACE_NAME, d.FILE_NAME, d.BYTES/1024/1024 SIZE_MB, d.AUTOEXTENSIBLE, d.MAXBYTES/1024/1024 MAXSIZE_MB, d.INCREMENT_BY*(v.BLOCK_SIZE/1024)/1024 INCREMENT_BY_MB
from dba_temp_files d,
 v$tempfile v
where d.FILE_ID = v.FILE#
order by d.TABLESPACE_NAME, d.FILE_NAME;

ALTER TABLESPACE TEMP_DWR ADD TEMPFILE '+DATA' SIZE 10G AUTOEXTEND ON NEXT 1G MAXSIZE 32767M;

/*
See Oracle Documentation for more info and Syntax:
https://docs.oracle.com/database/121/SQLRF/statements_3002.htm
*/
