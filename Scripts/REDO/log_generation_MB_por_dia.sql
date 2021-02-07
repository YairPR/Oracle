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

Generation Date      Total for the Day in MB
-------------------- -----------------------
13-OCT-20                              11538
14-OCT-20                               2866
15-OCT-20                               3093
16-OCT-20                               4115
17-OCT-20                               1731
