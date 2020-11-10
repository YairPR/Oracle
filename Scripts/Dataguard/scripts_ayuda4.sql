TROUBLESHOOTING A PHYSICAL STANDBY DATABASE:

NOTE: Pls check Metalink 232649.1 (Data Guard Gap Detection and Resolution)

On Standby server:

Run the below query to check the type of Standby database,
 PHYSCIAL or LOGICAL:

sqlplus "/ as sysdba"
select database_role from v$database;

If Physical Standby then follow:

Step1: Check which logs have not been applied:
======
alter session set nls_date_format='YYYY-MM-DD HH24:MI.SS';
SELECT SEQUENCE#, APPLIED, completion_time FROM V$ARCHIVED_LOG ORDER BY SEQUENCE#;

Step2:Check if there is a gap in the archive logs:
======
SELECT * FROM V$ARCHIVE_GAP;

If there is a gap, then it is most likely that the log has been compressed on the Primary server, and the Standby FAL service cannot retrieve the log.If so, then temporarily stop archivelog compression job on the primary and unzip the required archive logs. After a few minutes, the FAL service will retrieve the log and the Standby apply services will resume.Check the progress by running the SQL in step-1 above.
If the logs haven't been processed after 5-10 minutes, then you will have to perform the following tasks:

Step3: Copy the (zipped) log to the standby archive log destination on the Standby server, (unzip the archive), and register,

ALTER DATABASE REGISTER LOGFILE '/u01/oradata/stby/arch/arch_1_443.arc';

Step4: Check if this is a 'real-time apply standby:
=======
select recovery_mode from V$ARCHIVE_DEST_STATUS;

Step5: Stop/restart the standby apply services:
=======
alter database recover managed standby database cancel;

If a real-time apply standby then:
alter database recover managed standby database using current logfile disconnect from session;

Found this:
RECOVER MANAGED STANDBY DATABASE cancel;
ORA-16136: Managed Standby Recovery not active

RECOVER MANAGED STANDBY DATABASE disconnect from session;
Media recovery complete.

Else (non- realtime apply):
alter database recover managed standby database disconnect from session;

Check the progress by running the SQL in step-1 above.

Useful Standby query:
----------------------------
Startup standby database

startup nomount;
alter database mount standby database;
alter database recover managed standby database disconnect;

To remove a delay from a standby
alter database recover managed standby database cancel;
alter database recover managed standby database nodelay disconnect;

Cancel managed recovery
alter database recover managed standby database cancel;

Register a missing log file
alter database register physical logfile '<fullpath/filename>';

If FAL doesn't work and it says the log is already registered
alter database register or replace physical logfile '<fullpath/filename>';

If that doesn't work, try this...

shutdown immediate
startup nomount
alter database mount standby database;
alter database recover automatic standby database;

>> wait for the recovery to finish - then cancel

shutdown immediate
startup nomount
alter database mount standby database;
alter database recover managed standby database disconnect;


Check which logs are missing (Run this on the standby)

select local.thread#, local.sequence# from
       (select thread#, sequence# from  v$archived_log where dest_id=1) local where  local.sequence# not in
       (select sequence# from v$archived_log where dest_id=2 and thread# = local.thread#);

Disable/Enable archive log destinations
alter system set log_archive_dest_state_2 = 'defer';
alter system set log_archive_dest_state_2 = 'enable';


Turn on fal tracing on the primary db
alter system set LOG_ARCHIVE_TRACE = 128;

Stop the Data Guard broker
alter system set dg_broker_start=false;

Show the current instance role
select name, open_mode, database_role from v$database;
=====
Logical standby apply stop/start
Stop Logical standby >> alter database stop logical standby apply;

Start Logical standby >> alter database start logical standby apply;

See how up to date a physical standby is: (Run this on the primary)
set numwidth 15
select    max(sequence#) current_seq from    v$log;

Then run this on the standby
set numwidth 15
select max(applied_seq#) last_seq from v$archive_dest_status;

Display info about all log destinations (run on the primary)

set lines 100 set numwidth 15 column ID format 99 column "SRLs" format 99 column active format 99 col type format a4

select ds.dest_id id , ad.status , ds.database_mode db_mode , ad.archiver type , ds.recovery_mode , ds.protection_mode , ds.standby_logfile_count "SRLs" , ds.standby_logfile_active active , ds.archived_seq# from v$archive_dest_status ds , v$archive_dest ad where ds.dest_id = ad.dest_id and ad.status != 'INACTIVE' order by ds.dest_id;

Display log destinations options (run on the primary)

set numwidth 8 lines 100 column id format 99
select dest_id id , archiver , transmit_mode , affirm , async_blocks async , net_timeout net_time , delay_mins delay , reopen_secs reopen , register,binding from v$archive_dest order by dest_id;

List any standby redo logs
set lines 100 pages 999 col member format a70
select st.group# , st.sequence# , ceil(st.bytes / 1048576) mb , lf.member from v$standby_log st , v$logfile lf where st.group# = lf.group#;

Script for Standby archivelog monitoring….(removed the duplicate rows)

select arch.thread# "Thread", arch.sequence# "Last Sequence Received", appl.sequence# "Last Sequence Applied",  (arch.sequence# - appl.sequence#) "Difference" from
(select thread# ,sequence# from v$archived_log where (thread#,first_time ) in (select thread#,max(first_time) from v$archived_log group by thread#)) arch,
(select thread# ,sequence# from v$log_history where (thread#,first_time ) in (select thread#,max(first_time) from v$log_history group by thread#)) appl
where arch.thread# = appl.thread#
order by 1;
