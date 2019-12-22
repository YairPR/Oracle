SET ECHO        OFF
SET FEEDBACK    6
SET HEADING     ON
SET LINESIZE    256
SET PAGESIZE    50000
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

COLUMN disk_group_name    FORMAT a20                    HEAD 'Disk Group Name'
COLUMN disk_path          FORMAT a20                    HEAD 'Disk Path'
COLUMN reads              FORMAT 999,999,999,999        HEAD 'Reads'
COLUMN writes             FORMAT 999,999,999,999        HEAD 'Writes'
COLUMN read_errs          FORMAT 999,999,999            HEAD 'Read|Errors'
COLUMN write_errs         FORMAT 999,999,999            HEAD 'Write|Errors'
COLUMN read_time          FORMAT 999,999,999,999        HEAD 'Read|Time'
COLUMN write_time         FORMAT 999,999,999,999        HEAD 'Write|Time'
COLUMN bytes_read         FORMAT 999,999,999,999,999    HEAD 'Bytes|Read'
COLUMN bytes_written      FORMAT 999,999,999,999,999    HEAD 'Bytes|Written'

BREAK ON report ON disk_group_name SKIP 2

COMPUTE sum LABEL ""              OF reads writes read_errs write_errs read_time write_time bytes_read bytes_written ON disk_group_name
COMPUTE sum LABEL "Grand Total: " OF reads writes read_errs write_errs read_time write_time bytes_read bytes_written ON report

SELECT
    a.name                disk_group_name
  , b.path                disk_path
  , b.reads               reads
  , b.writes              writes
  , b.read_errs           read_errs 
  , b.write_errs          write_errs
  , b.read_time           read_time
  , b.write_time          write_time
  , b.bytes_read          bytes_read
  , b.bytes_written       bytes_written
FROM
    v$asm_diskgroup a JOIN v$asm_disk b USING (group_number)
ORDER BY
    a.name
/
