-- https://www.oracle-scripts.net/data-guard-troubleshooting/

This post provides help troubleshooting a standby database (dataguard). This article covers the following problems:

-Troubleshooting Log transport services
-Troubleshooting Redo Apply services
-Troubleshooting SQL Apply services
-Common Problems
-Log File Destination Failures
-Handling Logical Standby Database Failures
-Problems Switching Over to a Standby Database
-What to Do If SQL Apply Stops
-Troubleshooting a Logical Standby Database
-These SQL commands are compatible Oracle 18c, 12c, 11g and 10g.

Determine if archive logs of your DG environment are successfully being transferred to the standby
Run the following query:

--Primary
select dest_id,status,error from v$archive_dest
where target='STANDBY';

If all remote destinations have a status of VALID then proceed to next step.
Else proceed to Troubleshooting Log Transport Services.

How many archives need to be transfered from Primary?
Connected on primary:

select thread#, min(sequence#), min(min_date), count(*) from (
select thread#, sequence#, count(*), max(first_time) min_date
from v$archived_log
where first_time > sysdate – 2
group by thread#, sequence#
having count(*) <2
order by 1,2
)
group by thread#;

Determine if the standby is a Physical standby or a Logical Standby
To determine the standby type run the following query on the standby:

select database_role from v$database;

If the standby is a physical standby then proceed to Troubleshooting Redo
Apply. Else proceed to Troubleshooting Logical Apply.

Troubleshooting Log transport services
Verify that the primary database is in archive log mode and has automatic archiving enabled
select log_mode from v$database;

or in SQL*Plus

archive log list 

Verify that sufficient space exist in all archive destinations
The following query can be used to determine all local and mandatory destinations that need to be checked:

select dest_id,destination from v$archive_dest
where schedule='ACTIVE'
and (binding='MANDATORY' or target='PRIMARY');

Determine if the last log switch to any remote destinations resulted in an
error
select dest_id,status,error from v$archive_dest
where target='STANDBY';

Address any errors that are returned in the error column. Perform a log
switch and re-query to determine if the issue has been resolved.

Determine if any error conditions have been reached
Query the v$dataguard_status view:

select message, to_char(timestamp,’HH:MI:SS’) timestamp
from v$dataguard_status
where severity in ('Error','Fatal')
order by timestamp

Gather information about how the remote destinations are performing the
archival
select dest_id,archiver,transmit_mode,affirm,net_timeout,delay_mins,async_blocs
from v$archive_dest where target='STANDBY'

Determine the current sequence number, the last sequence archived, and the last sequence applied to a standby

Perhaps, the most important query to troubleshoot a stsandby configuration:

select ads.dest_id,
max(sequence#) « Current Sequence »,
max(log_sequence) « Last Archived »,
max(applied_seq#) « Last Sequence Applied »
from v$archived_log al, v$archive_dest ad, v$archive_dest_status ads
where ad.dest_id=al.dest_id
and al.dest_id=ads.dest_id
group by ads.dest_id

If you are remotely archiving using the LGWR process then the archived
sequence should be one higher than the current sequence. If remotely
archiving using the ARCH process then the archived sequence should be equal to the current sequence. The applied sequence information is updated at
log switch time.

Troubleshooting Redo Apply services
Verify that the last sequence# received and the last sequence# applied to
standby database
select max(al.sequence#) « Last Seq Recieved »,
max(lh.sequence#) « Last Seq Applied »
from v$archived_log al, v$log_history lh

If the two numbers are the same then the standby has applied all redo sent
by the primary. If the numbers differ by more than 1 then proceed to next step.

Verify that the standby is in the mounted state
select open_mode from v$database;

Determine if there is an archive gap on your physical standby database
By querying the V$ARCHIVE_GAP view as shown in the following query:

select * from v$archive_gap;

The V$ARCHIVE_GAP fixed view on a physical standby database only returns the next gap that is currently blocking redo apply from continuing.

After resolving the identified gap and starting redo apply, query the
V$ARCHIVE_GAP fixed view again on the physical standby database to
determine the next gap sequence, if there is one. Repeat this process
until there are no more gaps.

If v$archive_gap view does’nt exists:

WITH prod as (select max(sequence#) as seq from v_$archived_log where RESETLOGS_TIME = (select RESETLOGS_TIME from v_$database)), stby as (select max(sequence#) as seq,dest_id dest_id from v_$archived_log where first_change# > (select resetlogs_change# from v_$database) and applied = ‘YES’ and dest_id in (1,2) group by dest_id) select prod.seq-stby.seq,stby.dest_id from prod, stby

Verify that managed recovery is running
select process,status from v$managed_standby;

When managed recovery is running you will see an MRP process. If you do not see an MRP process then start managed recovery by issuing the following command:

recover managed standby database disconnect;

Some possible statuses for the MRP are listed below:

ERROR – This means that the process has failed. See the alert log or v$dataguard_status for further information.

WAIT_FOR_LOG – Process is waiting for the archived redo log to be completed. Switch an archive log on the primary and query v$managed_standby to see if the status changes to APPLYING_LOG.

WAIT_FOR_GAP – Process is waiting for the archive gap to be resolved. Review the alert log to see if FAL_SERVER has been called to resolve the gap.

APPLYING_LOG – Process is applying the archived redo log to the standby database.à

Troubleshooting SQL Apply services
Verify that log apply services on the standby are currently running.
To verify that logical apply is currently available to apply changes perform the following query:

SELECT PID, TYPE, STATUS, HIGH_SCN  FROM V$LOGSTDBY;

When querying the V$LOGSTDBY view, pay special attention to the HIGH_SCN column. This is an activity indicator. As long as it is changing each time you query the V$LOGSTDBY view, progress is being made. The STATUS column gives a text description of the current activity.

If the query against V$LOGSTDBY returns no rows then logical apply is not running. Start logical apply by issuing the following statement:

SQL> alter database start logical standby apply;

If the query against V$LOGSTDBY continues to return no rows then proceed to  next step.

Determine if there is an archive gap in your dataguard configuration
Query the DBA_LOGSTDBY_LOG view on the logical standby database.

SELECT SUBSTR(FILE_NAME,1,25) FILE_NAME, SUBSTR(SEQUENCE#,1,4) « SEQ# », FIRST_CHANGE#, NEXT_CHANGE#, TO_CHAR(TIMESTAMP, ‘HH:MI:SS’) TIMESTAMP, DICT_BEGIN BEG, DICT_END END, SUBSTR(THREAD#,1,4) « THR# » FROM DBA_LOGSTDBY_LOG ORDER BY SEQUENCE#;

Copy the missing logs to the logical standby system and register them using the ALTER DATABASE REGISTER LOGICAL LOGFILE statement on your logical standby database. For example:

SQL> ALTER DATABASE REGISTER LOGICAL LOGFILE ‘/u01/oradata/arch/myarc_57.arc’;

After you register these logs on the logical standby database, you can restart log apply services. The DBA_LOGSTDBY_LOG view on a logical standby database only returns the next gap that is currently blocking SQL apply operations from continuing.

After resolving the identified gap and starting log apply services, query the DBA_LOGSTDBY_LOG view again on the logical standby database to determine the next gap sequence, if there is one. Repeat this process until there are no more gaps.

Verify iflogical apply is receiving errors while performing apply operations.
Log apply services cannot apply unsupported DML statements, DDL statements and Oracle supplied packages to a logical standby database in SQL apply mode. When an unsupported statement or package is encountered, SQL apply operations stop. To determine if SQL apply has stopped due to errors you should query the DBA_LOGSTDBY_EVENTS view. When querying the view, select the columns in order by EVENT_TIME. This ordering ensures that a shutdown
failure appears last in the view. For example:

SQL> SELECT XIDUSN, XIDSLT, XIDSQN, STATUS, STATUS_CODE
FROM DBA_LOGSTDBY_EVENTS
WHERE EVENT_TIME =
(SELECT MAX(EVENT_TIME) FROM DBA_LOGSTDBY_EVENTS);

If an error requiring database management occurred (such as adding a tablespace, datafile, or running out of space in a tablespace), then you can fix the problem manually and resume SQL apply.

If an error occurred because a SQL statement was entered incorrectly, conflicted with an existing object, or violated a constraint then enter the correct SQL statement and use the DBMS_LOGSTDBY.SKIP_TRANSACTION procedure to ensure that the incorrect statement is ignored the next time SQL apply operations are run.

Query DBA_LOGSTDBY_PROGRESS to verify that log apply services is progressing
The DBA_LOGSTDBY_PROGRESS view describes the progress of SQL apply operations on the logical standby databases. For example:

SQL> SELECT APPLIED_SCN, APPLIED_TIME, READ_SCN, READ_TIME,
NEWEST_SCN, NEWEST_TIME
FROM DBA_LOGSTDBY_PROGRESS;

The APPLIED_SCN indicates that committed transactions at or below that SCN have been applied. The NEWEST_SCN is the maximum SCN to which data could be applied if no more logs were received. This is usually the MAX(NEXT_CHANGE#)-1
from DBA_LOGSTDBY_LOG when there are no gaps in the list. When the value of NEWEST_SCN and APPLIED_SCN are the equal then all available changes have been applied. If you APPLIED_SCN is below NEWEST_SCN and is increasing then
SQL apply is currently processing changes.

Verify that the table that is not receiving rows is not listed in the DBA_LOGSTDBY_UNSUPPORTED.
The DBA_LOGSTDBY_USUPPORTED view lists all of the tables that contain datatypes not supported by logical standby databases in the current release. These tables are not maintained (will not have DML applied) by the logical
standby database. Query this view on the primary database to ensure that those tables necessary for critical applications are not in this list. If the primary database includes unsupported tables that are critical, consider using a physical standby database.

