set line 2000
set pagesize 2000
set timing on
column input_type format a15
column START_TIME format a20
column END_TIME format a20
column status format a25
column device format a10
column INPUT_BYTES format a14
column output_bytes format a14

SELECT INPUT_TYPE, 
SUBSTR(STATUS,1,42) STATUS,
TO_CHAR(START_TIME,'YYYYMMDD HH24:MI:SS') START_TIME, 
TO_CHAR(END_TIME,'YYYYMMDD HH24:MI:SS') END_TIME, 
ELAPSED_SECONDS, 
SUBSTR(output_device_type,1,10) DEVICE,
substr(to_char(input_bytes_display),1,10) input_bytes,
substr(to_char(output_bytes_display),1,10) output_bytes
from 
V$RMAN_BACKUP_JOB_DETAILS 
WHERE 
-- input_type like '%DB%'
-- status='COMPLETED'
-- status<>'COMPLETED'
-- and 
-- where 
-- and OUTPUT_BYTES > 0 
-- and 
to_char(START_TIME,'YYYYMMDD') >= '20191101'
and to_char(START_TIME,'YYYYMMDD') <= '20191219'
--and to_char(START_TIME,'YYYYMMDD') <= TRUNC(SYSDATE)
-- and STATUS <>'FAILED'
order by START_TIME;
