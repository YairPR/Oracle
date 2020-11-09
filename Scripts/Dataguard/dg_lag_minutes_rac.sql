— dg_lag_minutes.sql — takes ORACLE_SID as parameter
set echo on feed on term on
set linesize 120
col PRIMARY_TIME format a20
col STANDBY_COMPLETION_TIME format a23
spool dg_lag_minutes_&1..sql.log.txt
SELECT
prim.thread# thread,
prim.seq primary_seq,
to_char(prim.tm, ‘DD-MON-YYYY HH24:MI:SS’) primary_time,
tgt.thread# standby_thread,
tgt.seq standby_seq,
to_char(tgt.tm, ‘DD-MON-YYYY HH24:MI:SS’) standby_completion_time,
prim.seq – tgt.seq seq_gap,
( prim.tm – tgt.tm ) * 24 * 60 lag_minutes
FROM
(
SELECT
thread#,
MAX(sequence#) seq,
MAX(completion_time) tm
FROM
v$archived_log
GROUP BY
thread#
) prim,
(
SELECT
thread#,
MAX(sequence#) seq,
MAX(completion_time) tm
FROM
v$archived_log
WHERE
dest_id IN (
SELECT
dest_id
FROM
v$archive_dest
WHERE
target = ‘STANDBY’
)
AND applied = ‘YES’
GROUP BY
thread#
) tgt
WHERE
prim.thread# = tgt.thread#;
spool off
— end of file
