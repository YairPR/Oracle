---- Ver si hay backup rman
set pages 20000 lines 260
col STATUS format a24
col hrs format 999.99
col start_time for a18
col end_time for a18
select
SESSION_KEY, INPUT_TYPE, STATUS,
to_char(START_TIME,'yyyy-mm-dd hh24:mi') start_time,
to_char(END_TIME,'yyyy-mm-dd hh24:mi') end_time,
elapsed_seconds/3600 hrs
from V$RMAN_BACKUP_JOB_DETAILS
order by session_key;
