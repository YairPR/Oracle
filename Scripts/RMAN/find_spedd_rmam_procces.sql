--Query to Find Speed of RMAN backup :

--Depending on whether RMAN is running Synch I/O or Asynch I/O to the target
--(The BlockRate is the number of times RMAN went into “Wait” because I/O was blocked)

set linesize 132
set pages60

col SizeMB format 999,999
col Effective_Bytes_Per_Second format 9,999,999,999
col BlockRate format 999.99

spool RMAN_Backup_Speed

tti 'Input Speeds'
select open_time, bytes/1048576 SizeMB, elapsed_time, io_count, short_waits, long_waits, long_waits*100/io_count BlockRate, effective_bytes_per_second
from v$backup_async_io
where type = 'INPUT'
and open_time > sysdate-7
and status = 'FINISHED'
order by 1
/

tti 'Output Speeds'
select open_time, bytes/1048576 SizeMB, elapsed_time, io_count, short_waits, long_waits, long_waits*100/io_count BlockRate, effective_bytes_per_second
from v$backup_async_io
where type = 'OUTPUT'
and open_time > sysdate-7
and status = 'FINISHED'
order by 1
/

tti 'Aggregate Speeds'
select open_time, bytes/1048576 SizeMB, elapsed_time, io_count, short_waits, long_waits, long_waits*100/io_count BlockRate, effective_bytes_per_second
from v$backup_async_io
where type = 'AGGREGATE'
and open_time > sysdate-7
and status = 'FINISHED'
order by 1
/

tti off
spool off

Reference: 
