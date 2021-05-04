col name for a32
col size_m for 999,999,999
col reclaimable_m for 999,999,999
col used_m for 999,999,999
col pct_used for 999
SELECT name
, ceil( space_limit / 1024 / 1024) SIZE_M
, ceil( space_used / 1024 / 1024) USED_M
, ceil( space_reclaimable / 1024 / 1024) RECLAIMABLE_M
, decode( nvl( space_used, 0),
 0, 0
 , ceil ( ( ( space_used - space_reclaimable ) / space_limit) * 100) ) PCT_USED
 FROM v$recovery_file_dest
ORDER BY name
/

NAME				       SIZE_M	    USED_M RECLAIMABLE_M PCT_USED
-------------------------------- ------------ ------------ ------------- --------
+RECOC1 			   12,288,000	 6,104,454     5,506,298	5


- Use (MB) of FRA
set lines 100
col name format a60
select 
   name,
  floor(space_limit / 1024 / 1024) "Size MB",
  ceil(space_used / 1024 / 1024) "Used MB"
from v$recovery_file_dest;

NAME								Size MB    Used MB
------------------------------------------------------------ ---------- ----------
+RECOC1 						       12288000    6104454


-- FRA Occupants
SELECT * FROM V$FLASH_RECOVERY_AREA_USAGE;

FILE_TYPE	     PERCENT_SPACE_USED PERCENT_SPACE_RECLAIMABLE NUMBER_OF_FILES
-------------------- ------------------ ------------------------- ---------------
CONTROL FILE			      0 			0		0
REDO LOG			     .8 			0	       24
ARCHIVED LOG			  36.44 		    36.44	     3726
BACKUP PIECE			    .01 		      .01		6
IMAGE COPY			      0 			0		0
FLASHBACK LOG			  12.44 		     8.37	      373
FOREIGN ARCHIVED LOG		      0 			0		0

7 rows selected.

-- Location and size of the FRA
show parameter db_recovery_file_dest

-- Size, usage, Reclaimable space used 
SELECT 
  ROUND((A.SPACE_LIMIT / 1024 / 1024 / 1024), 2) AS FLASH_IN_GB, 
  ROUND((A.SPACE_USED / 1024 / 1024 / 1024), 2) AS FLASH_USED_IN_GB, 
  ROUND((A.SPACE_RECLAIMABLE / 1024 / 1024 / 1024), 2) AS FLASH_RECLAIMABLE_GB,
  SUM(B.PERCENT_SPACE_USED)  AS PERCENT_OF_SPACE_USED
FROM 
  V$RECOVERY_FILE_DEST A,
  V$FLASH_RECOVERY_AREA_USAGE B
GROUP BY
  SPACE_LIMIT, 
  SPACE_USED , 
  SPACE_RECLAIMABLE ;
  
  FLASH_IN_GB FLASH_USED_IN_GB FLASH_RECLAIMABLE_GB PERCENT_OF_SPACE_USED
----------- ---------------- -------------------- ---------------------
      12000	     5961.38		  5377.24		  49.69


-- After that you can resize the FRA with:
-- ALTER SYSTEM SET db_recovery_file_dest_size=xxG;

-- Or change the FRA to a new location (new archives will be created to this new location):
-- ALTER SYSTEM SET DB_RECOVERY_FILE_DEST='/u....';
