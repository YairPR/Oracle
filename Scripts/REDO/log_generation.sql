SET PAUSE ON
SET PAUSE 'Press Return to Continue'
SET PAGESIZE 60
SET LINESIZE 300
SET VERIFY OFF
 
COL "Generation Date" FORMAT a20
 
SELECT TRUNC(completion_time)  "Generation Date" ,
   round(SUM(blocks*block_size)/1048576,0) "Total for the Day in MB"
FROM gv$archived_log
GROUP BY TRUNC(completion_time)
ORDER BY TRUNC(completion_time)
/
