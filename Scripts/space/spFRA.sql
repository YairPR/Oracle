-- Use (MB) of FRA
set lines 100
col name format a60

select 
   name,
  floor(space_limit / 1024 / 1024) "Size MB",
  ceil(space_used / 1024 / 1024) "Used MB"
from v$recovery_file_dest;

-- FRA Occupants
SELECT * FROM V$FLASH_RECOVERY_AREA_USAGE;

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

-- After that you can resize the FRA with:
-- ALTER SYSTEM SET db_recovery_file_dest_size=xxG;

-- Or change the FRA to a new location (new archives will be created to this new location):
-- ALTER SYSTEM SET DB_RECOVERY_FILE_DEST='/u....';
