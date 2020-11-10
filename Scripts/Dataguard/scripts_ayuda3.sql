Dataguard Troubleshooting / Commands
=====================================

Revisar parametros:
show parameter fal;
!tnsping <server/client>
show parameter dump;
show parameter listener;
show parameter service;
show parameter log_archive_dest_2;
show parameter log_archive_dest_state_2;
show parameter dg_broker_start;

On Primary Database
===================
select DEST_ID,DEST_NAME,DESTINATION,TARGET,STATUS,ERROR 
from v$archive_dest where DESTINATION dest_id=2;
/
SELECT THREAD# "Thread",SEQUENCE# "Last Sequence generated"  FROM V$ARCHIVED_LOG  WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$ARCHIVED_LOG GROUP BY THREAD#)  ORDER BY 1
/
select max(sequence#),thread# from gv$log group by thread#;

set numwidth 15
select max(sequence#) current_seq,archived,status from v$log;
/


On Standby Database
===================
SELECT THREAD#, LOW_SEQUENCE#, HIGH_SEQUENCE# FROM V$ARCHIVE_GAP
/
select PROCESS,STATUS,THREAD#,SEQUENCE#,BLOCK#,BLOCKS,DELAY_MINS 
from v$managed_standby;
/
select max(sequence#),thread# from gv$archived_log 
where applied='YES' group by thread#;
/
set numwidth 15
select max(applied_seq#) last_seq from v$archive_dest_status;
/

FIND GAP
--------
select thread#,low_sequence#,high_sequence# from v$archive_log;

LISTNER VERIFICATION FROM PRIMATY DB
------------------------------------
select status,error from v$archive_dest where dest_name='LOG_ARCHIVE_DEST_2';

DEFER Log Shipping
------------------
alter system set log_archive_dest_state_2='DEFER' scope=both;

alter system set dg_broker_start=false;

ENABLE Log Shipping
-------------------
alter system set log_archive_dest_state_2='ENABLE' scope=both;

alter system set dg_broker_start=true;

DELAY CHANGE
------------
SQL> alter system set log_archive_dest_2='ARCH DELAY=15 
OPTIONAL REOPEN=60 SERVICE=S1';


ARCHIVE_LAG_TARGET tells Oracle to make sure to switch a log every n seconds
----------------------------------------------------------------------------
ALTER SYSTEM SET ARCHIVE_LAG_TARGET = 1800 SCOPE=BOTH;
This sets the maximum lag to 30 mins.


On Primary to Display info about all log destinations
=====================================================
set pages 300 lines 300
set numwidth 15
column ID format 99
column "SRLs" format 99
column active format 99
col type format a4
select ds.dest_id id,ad.status,ds.database_mode db_mode,ds.recovery_mode, ds.protection_mode,
ds.standby_logfile_count "SRLs",ds.standby_logfile_active active,
ds.archived_seq# from v$archive_dest_status ds,v$archive_dest ad 
where ds.dest_id = ad.dest_id and ad.status != 'INACTIVE'  
order by ds.dest_id
/

On Primary to Display log destinations options
==============================================
set pages 300 lines 300
set numwidth 10
column id format 99
select dest_id id ,archiver,transmit_mode,affirm,
async_blocks async,net_timeout net_time,delay_mins delay, 
reopen_secs reopen,register,binding from v$archive_dest order by dest_id
/


==================================================================================================

Standby Database
================
select NAME,DATABASE_ROLE,OPEN_MODE,PROTECTION_MODE,PROTECTION_LEVEL, CURRENT_SCN,FLASHBACK_ON,FORCE_LOGGING from v$database;

Some possible statuses for the MRP
----------------------------------
ERROR - This means that the process has failed. 
See the alert log or v$dataguard_status for further information.

WAIT_FOR_LOG - Process is waiting for the archived redo log to be completed. 
Switch an archive log on the primary and requery 
v$managed_standby to see if the status changes to APPLYING_LOG.

WAIT_FOR_GAP - Process is waiting for the archive gap to be resolved. 
Review the alert log to see if FAL_SERVER has been called to resolve the gap.

APPLYING_LOG - Process is applying the archived redo log 
to the standby database.

CHECK MANAGED RECOVERY PROCESS : SHOWS STATUS OF ARCH,RFS,MRP PROCESS.
------------------------------
select inst_id,process,status,client_process,thread#,sequence#,block#,
blocks,delay_mins from gv$managed_standby;

select * from gv$active_instances;

!ps -ef|grep -i mrp

STARTING MRP0
-------------
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

STOPING MRP0
------------
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

To Display MRP0 Speed
---------------------
set pages 300 lines 300
Col Values For A65
Col Recover_start For A21
Select To_char(START_TIME,'Dd.Mm.Yyyy Hh24:Mi:ss') "Recover_start",
To_char(Item)||' = '||To_char(Sofar)||' '||To_char(Units)||' '||
 To_char(TIMESTAMP,'Dd.Mm.Yyyy Hh24:Mi') "Values" 
From V$Recovery_progress Where Start_time=(Select Max(Start_time) From V$Recovery_progress);

checking log transfer and apply
-------------------------------
SELECT SEQUENCE#,FIRST_TIME,NEXT_TIME,APPLIED
 FROM V$ARCHIVED_LOG ORDER BY SEQUENCE# ;
select count(*) from V$ARCHIVED_LOG where applied='NO';
/

TIME TAKEN TO APPLY A LOG
-------------------------
set pages 300 lines 300

select TIMESTAMP,completion_time "ArchTime",SEQUENCE#,
round((blocks*block_size)/(1024*1024),1) "SizeM",
round((TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP) 
OVER (order by TIMESTAMP))*24*60*60,1) "Diff(sec)",
round((blocks*block_size)/1024/ decode(((TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP) OVER (order by TIMESTAMP))*24*60*60),0,1, (TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP) OVER (order by TIMESTAMP))*24*60*60),1) "KB/sec", round((blocks*block_size)/(1024*1024)/ decode(((TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP)
OVER (order by TIMESTAMP))*24*60*60),0,1, (TIMESTAMP-lag(TIMESTAMP,1,TIMESTAMP) OVER (order by TIMESTAMP))*24*60*60),3) "MB/sec",round(((lead(TIMESTAMP,1,TIMESTAMP) over (order by TIMESTAMP))-completion_time)*24*60*60,1) "Lag(sec)" from v$archived_log a, v$dataguard_status dgs where a.name = replace(dgs.MESSAGE,'Media Recovery Log ','') and dgs.FACILITY = 'Log Apply Services' order by TIMESTAMP desc;
/

CHECKING FOR DATAGAURD ERROR
----------------------------
set pages 300 lines 300
column Timestamp Format a20
column Facility  Format a24
column Severity  Format a13
column Message   Format a80 trunc

Select to_char(timestamp,'YYYY-MON-DD HH24:MI:SS') Timestamp,Facility,Severity,error_code,message_num,Message from v$dataguard_status where severity in ('Error','Fatal') order by Timestamp;

select  *  from v$ARCHIVE_GAP;

--OR---
Here is another script with v$dataguard_status:

select *
  from (select TIMESTAMP,
               completion_time "ArchTime",
               SEQUENCE#,
               round((blocks * block_size) / (1024 * 1024), 1) "Size Meg",
               round((TIMESTAMP - lag(TIMESTAMP, 1, TIMESTAMP)
                      OVER(order by TIMESTAMP)) * 24 * 60 * 60,
                     1) "Diff(sec)",
               round((blocks * block_size) / 1024 /
                     decode(((TIMESTAMP - lag(TIMESTAMP, 1, TIMESTAMP)
                             OVER(order by TIMESTAMP)) * 24 * 60 * 60),
                            0,
                            1,
                            (TIMESTAMP - lag(TIMESTAMP, 1, TIMESTAMP)
                             OVER(order by TIMESTAMP)) * 24 * 60 * 60),
                     1) "KB/sec",
               round((blocks * block_size) / (1024 * 1024) /
                     decode(((TIMESTAMP - lag(TIMESTAMP, 1, TIMESTAMP)
                             OVER(order by TIMESTAMP)) * 24 * 60 * 60),
                            0,
                            1,
                            (TIMESTAMP - lag(TIMESTAMP, 1, TIMESTAMP)
                             OVER(order by TIMESTAMP)) * 24 * 60 * 60),
                     3) "MB/sec",
               round(((lead(TIMESTAMP, 1, TIMESTAMP) over(order by TIMESTAMP)) -
                     completion_time) * 24 * 60 * 60,
                     1) "Lag(sec)"
          from v$archived_log a, v$dataguard_status dgs
         where a.name = replace(dgs.MESSAGE, 'Media Recovery Log ', '')
           and dgs.FACILITY = 'Log Apply Services'
         order by TIMESTAMP desc)
 where rownum < 10;

Finding Missing Logs on Standby
-------------------------------
select local.thread#,local.sequence# from (select thread#,sequence# from v$archived_log where dest_id=1) local where local.sequence# not in (select sequence# from v$archived_log where dest_id=2 and thread# = local.thread#)
/

Check which logs have not been applied
--------------------------------------
alter session set nls_date_format='YYYY-MM-DD HH24:MI.SS';
SELECT SEQUENCE#, APPLIED, completion_time FROM V$ARCHIVED_LOG ORDER BY SEQUENCE#;

REGISTRYING LOGFILE
-------------------
alter database register logfile '/file/path/';

RECOVERY PROGRESS ON STANDBY SITE
---------------------------------
v$managed_standby
v$archived_standby

v$archive_dest_status -  TO FIND THE LAST ARCHIVED LOG RECEIVED AND APPLIED ON THIS SITE.
select archived_thread#,archived_seq#,applied_thread#,applied_seq# from v$archive_dest_status;

v$log_history
select max(sequence#),latest_archive_log from v$log_history;

v$archived_log - individual archive log
select thread#,sequence#,applied,registrar from v$archived_log;

standby_file_management - playes when attributes of datafiles are modified primary site.
-IF IT IS RAW DEVICE STANDBY_FILE_MANAGEMENT SHOULD BE MANUAL.OTHERWISE AUTO

http://oraclerac.weebly.com/standby.html

==================================================================================================================
