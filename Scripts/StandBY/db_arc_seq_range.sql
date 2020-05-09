--https://weidongzhou.wordpress.com/2014/09/20/script-to-identify-the-restore-and-recover-point-for-archive-logs/

col "Restore Command" for a100
col "Applied Logs" for a100
col "Catalog Logs" for a100
col "Recover Command" for a80
select ' restore archivelog from logseq ' || applied_arc.startNo || ' until logseq ' || catalog_arc.endNo || ' thread=' || catalog_arc.thread# || ';' "Restore Command"
from
--(select thread#,max(sequence#) + 1 startNo from gv$archived_log where applied='YES' group by thread#) applied_arc,
(select thread#,max(sequence#) startNo from gv$archived_log where applied='YES' group by thread#) applied_arc,
(select thread#, max(sequence#) endNo from v$backup_archivelog_details group by thread#) catalog_arc
where applied_arc.thread# = catalog_arc.thread#;
 
prompt '=========== Archive Log Info ============='
select distinct 'Thread ' || thread# || ': last applied archive log ' || sequence# || ' at ' || to_char(next_time, 'MON/DD/YYYY HH24:MI:SS') || ' next change# ' || next_change# "Applied Logs"
from v$archived_log
where thread# || '_' || sequence# in
(select thread# || '_' || max(sequence#) from v$archived_log where applied='YES' group by thread#)
--and applied='YES'
;
select 'Thread ' || thread# || ': last cataloged archive log ' || sequence# || ' at ' || to_char(next_time, 'MON/DD/YYYY HH24:MI:SS') || ' next change# ' || next_change# "Catalog Logs"
from v$backup_archivelog_details
where thread# || '_' || sequence# in
(select thread# || '_' || max(sequence#) from v$backup_archivelog_details group by thread#)
;
 
prompt '=========== recover point ================'
--select 'recover database until sequence ' || seq# || ' thread ' || thread# || ' delete archivelog maxsize 4000g; ' Content
select 'set until sequence ' || seq# || ' thread ' || thread# || '; ' || chr(13)|| chr(10) || 'recover database delete archivelog maxsize 4000g; ' "Recover Command"
from (
select * from (
select thread#, sequence# + 1 seq#, next_change# from (
select * from v$backup_archivelog_details
where thread# || '_' || sequence# in
(select thread# || '_' || max(sequence#) from v$backup_archivelog_details group by thread#)
)
order by next_change#
)
where
rownum = 1
)
;
