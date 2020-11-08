--http://select-star-from.blogspot.com/2013/05/finding-archivelog-names-using-scn.html

You can get the archivelog sequence number containing a specific scn.

select sequence# from v$archived_log where &scn between FIRST_CHANGE# and NEXT_CHANGE#;

Finding Archivelog Names using the SCN
How to find the Archivelog names using the SCN
During database recovery,we may have a SCN number and need to know the archivelog names. 

set pages 300 lines 300
col first_change# for 9,999,999,999
col next_change# for 9,999,999,999

alter session set nls_date_format='DD-MON-RRRR HH24:MI:SS';

select name, thread#, sequence#, status, first_time, next_time, first_change#, next_change# from v$archived_log
where <scn_number> between first_change# and next_change#;

SEQUENCE# number usually shows up on the archivelog name. 

If you see 'D' in the STATUS column, 
the archive log has been deleted from the disk. You may need to restore it from the tape.
rman target /
list backup of archivelog from logseq=<from_number> until logseq=<until_number>; 
restore archivelog from logseq=<from_number> until logseq=<until_number>;
