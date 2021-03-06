-- https://valehagayev.wordpress.com/2016/07/09/dataguard-commands-and-sql-scripts/
=============================
PHYSICAL STANDBY COMMANDS  ==
=============================

To start redo apply in foreground:
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE;

To stop redo apply process on the Standby database (to stop MRP):
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

To start real-time redo apply:
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

To start redo apply in background:
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
or
SQL> RECOVER MANAGED STANDBY DATABASE DISCONNECT;

To check redo apply  and Media recovery service status:
SQL> SELECT PROCESS,STATUS, THREAD#,SEQUENCE#, BLOCK#, BLOCKS FROM V$MANAGED_STANDBY ;

If managed standby recovery is not running or not started with real-time apply, restart managed recovery with real-time apply enabled:
--stop
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
--start
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT

To gather Data Guard configuration information(standby)
SQL> SELECT DATABASE_ROLE,OPEN_MODE, PROTECTION_MODE FROM V$DATABASE 

DATABASE_ROLE OPEN_MODE PROTECTION_MODE
---------------- -------------------- --------------------
PHYSICAL STANDBY MOUNTED MAXIMUM PERFORMANCE

SQL> SELECT RECOVERY_MODE FROM V$ARCHIVE_DEST_STATUS WHERE RECOVERY_MODE!='IDLE';

RECOVERY_MODE
-----------------------
MANAGED REAL TIME APPLY

To calculate the Redo bytes per second -- revisar script

 SELECT SUM (BLOCKS * BLOCK_SIZE)/1024/1024/60/60/30 REDO_MB_PER_SEC
 FROM GV$ARCHIVED_LOG
 WHERE FIRST_TIME BETWEEN TO_DATE ('08.11.2020', 'DD.MM.YYYY')
 AND TO_DATE ('08.11.2020', 'DD.MM.YYYY');
 
To check status of Data Guard synchronization(standby):

SQL> SELECT NAME, VALUE FROM V$DATAGUARD_STATS;

NAME VALUE
--------------------- -------------------------------
transport lag          +00 00:00:00
apply lag              +00 00:00:00
apply finish time      +00 00:00:00.000
estimated startup time 32

To verify there is no log file gap between the primary and the standby database:

SQL> SELECT STATUS, GAP_STATUS FROM V$ARCHIVE_DEST_STATUS WHERE DEST_ID = 3;

STATUS GAP_STATUS
--------- ------------------------
VALID NO GAP
 

To verify that the primary database can be switched to the standby role:

A value of TO STANDBY or SESSIONS ACTIVE indicates that the primary database can be switched to the standby role. 
f neither of these values is returned, a switchover is not possible because redo transport is either misconfigured or
is not functioning properly.

SQL> SELECT SWITCHOVER_STATUS FROM V$DATABASE; 

SWITCHOVER_STATUS
--------------------
TO STANDBY

You can use verify command to verfy switchover
This comman will generate warnings in alert log file and you can check it before switchover

SQL> ALTER DATABASE SWITCHOVER to STBY_DB_SID VERIFY;
To convert the primary database into a physical standby :

Before switchover the current control file is backed up to the current SQL session trace file and it possible to reconstruct a current control file, if necessary.

SQL> ALTER DATABASE COMMIT TO SWITCHOVER TO PHYSICAL STANDBY WITH SESSION SHUTDOWN;

Database altered.
To verify Managed Recovery is running on the standby :

SQL> SELECT PROCESS FROM V$MANAGED_STANDBY WHERE PROCESS LIKE 'MRP%'; 

PROCESS
---------
MRP0
To show information about the protection mode, the protection level, the role of the database, and switchover status:

SQL> SELECT DATABASE_ROLE, DB_UNIQUE_NAME INSTANCE, OPEN_MODE, PROTECTION_MODE, PROTECTION_LEVEL, SWITCHOVER_STATUS FROM V$DATABASE;

DATABASE_ROLE     INSTANCE    OPEN_MODE    PROTECTION_MODE     PROTECTION_LEVEL     SWITCHOVER_STATUS
---------------- ---------- ------------ -------------------- -------------------- -------------------- --------------------
PRIMARY           TESTCDB    READ WRITE    MAXIMUM PERFORMANCE MAXIMUM PERFORMANCE   TO STANDBY
On the standby database, query the V$ARCHIVED_LOG view to identify existing files in the archived redo log.

SQL> SELECT SEQUENCE#, FIRST_TIME, NEXT_TIME FROM V$ARCHIVED_LOG ORDER BY SEQUENCE#;
Or
SQL> SELECT THREAD#, MAX(SEQUENCE#) AS "LAST_APPLIED_LOG" FROM V$LOG_HISTORY GROUP BY THREAD#;
On the standby database, query the V$ARCHIVED_LOG view to verify the archived redo log files were applied.

SELECT SEQUENCE#,APPLIED FROM V$ARCHIVED_LOG ORDER BY SEQUENCE#;
 

To determine which log files were not received by the standby site.

SQL> SELECT LOCAL.THREAD#, LOCAL.SEQUENCE#
FROM (SELECT THREAD#, SEQUENCE#
FROM V$ARCHIVED_LOG
WHERE DEST_ID = 1) LOCAL
WHERE LOCAL.SEQUENCE# NOT IN (SELECT SEQUENCE#
FROM V$ARCHIVED_LOG
WHERE DEST_ID = 2 AND THREAD# = LOCAL.THREAD#);
 

Archivelog difference: Run this on the primary database. (not for real-time apply):

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';
SELECT A.THREAD#,
 B.LAST_SEQ,
 A.APPLIED_SEQ,
 A.LAST_APP_TIMESTAMP,
 B.LAST_SEQ - A.APPLIED_SEQ ARC_DIFF
 FROM ( SELECT THREAD#,
 MAX (SEQUENCE#) APPLIED_SEQ,
 MAX (NEXT_TIME) LAST_APP_TIMESTAMP
 FROM GV$ARCHIVED_LOG
 WHERE APPLIED = 'YES'
 GROUP BY THREAD#) A,
 ( SELECT THREAD#, MAX (SEQUENCE#) LAST_SEQ
 FROM GV$ARCHIVED_LOG
 GROUP BY THREAD#) B
 WHERE A.THREAD# = B.THREAD#;

 THREAD#   LAST_SEQ    APPLIED_SEQ  LAST_APP_TIMESTAMP   ARC_DIFF
---------- ---------- -----------   --------------------- ----------
 1         21282      21281         09-IYUL-2016 12:06:5     1
 2         23747      23746         09-IYUL-2016 12:16:13    1

2 rows selected.

To check archive log apply  on primary database:

SQL> SET LINESIZE 150
SET PAGESIZE 999
COL NAME FORMAT A60
COL DEST_TYPE FORMAT A10
COL ARCHIVED FORMAT A10
COL APPLIED FORMAT A10

SELECT SEQUENCE#,
NAME,
DEST_ID ,
CASE WHEN STANDBY_DEST = 'YES' THEN 'Standby' ELSE 'Local' END
AS DEST_TYPE ,
ARCHIVED ,
APPLIED
FROM V$ARCHIVED_LOG
WHERE SEQUENCE# > (SELECT MAX (SEQUENCE#)
FROM V$ARCHIVED_LOG
WHERE STANDBY_DEST = 'YES' AND APPLIED = 'YES')
ORDER BY SEQUENCE# , DEST_ID ;


 SEQUENCE#  NAME                                                          DEST_ID  DEST_TYPE  ARCHIVED APPLIED
---------- -------------------------------------------------------------- -------  ---------- -------- --------
 23748      +FRA/TESTCDB/ARCHIVELOG/2016_07_09/thread_2_seq_23748.10041.9   1      Local        YES       NO
 23748      +DATA/TESTCDB/ARCHIVELOG/2016_07_09/thread_2_seq_23748.10062.   2      Local        YES       NO
 23748      TESTSTB                                                         3      Standby      YES       NO

3 rows selected.

 
=======================
DG BROKER COMMANDS ====
======================= 

How to configure Data Guard broker:

1.Start the DMON process on both the primary and standby databases:

SQL> ALTER SYSTEM SET DG_BROKER_START=TRUE SCOPE=BOTH;
System altered.

2.Set the log_archive_dest_2 settings from both the Primary and Standby databases
to be nothing , then try to create the broker configuration (it will automatically 
set the log_archive_dest_n when you'll add a database to the configuration)

SQL> ALTER SYSTEM SET LOG_ARCHIVE_DEST_2='';
System altered.

Connect DGMGRL on the primary DB and create the configuration 

[oracle@primary ~]$ dgmgrl
DGMGRL for Linux: Version 12.1.0.2.0 - 64bit Production
Copyright (c) 2000, 2013, Oracle. All rights reserved.
Welcome to DGMGRL, type "help" for information.
DGMGRL> connect sys/test
Connected as SYSDG.

DGMGRL> CREATE CONFIGURATION 'TEST' AS PRIMARY DATABASE IS 'DB12C' CONNECT IDENTIFIER IS DB12C;
Configuration "TEST" created with primary database "DB12C"

Next add a standby database to the Data Guard broker configuration:

DGMGRL> ADD DATABASE 'db12c_stby' AS CONNECT IDENTIFIER IS 'db12c_stby';
Database "db12c" added

Enable dataguard broker configuration 

DGMGRL> enable configuration;
Enabled.

DGMGRL> show configuration;

Configuration - TEST

 Protection Mode: MaxPerformance
 Members:
 db12c - Primary database
 DB12C_STBY - Physical standby database 

Fast-Start Failover: DISABLED

Configuration Status:
SUCCESS (status updated 40 seconds ago)
 

To remove DG broker configuration:

DGMGRL> remove configuration;
Removed configuration
Rename the database name in the Data Guard broker as follows:

DGMGRL> edit database 'db12c_stby' rename to 'STBY';
To turn off redo transport to all remote destinations on the primary database:

 DGMGRL> edit database 'DB12C' SET STATE="LOG-TRANSPORT-OFF";
To stop and start redo transport services to specific standby databases:

DGMGRL> edit database 'db12c_stby' SET PROPERTY 'LogShipping'='OFF';
Property "LogShipping" updated
DGMGRL> SHOW DATABASE 'db12c_stby' 'LogShipping';
 LogShipping = 'OFF'
DGMGRL> edit database 'db12c_stby' SET PROPERTY 'LogShipping'='ON';
Property "LogShipping" updated
DGMGRL> SHOW DATABASE 'db12c_stby' 'LogShipping';
 LogShipping = 'ON'
To change the state of the standby database to read-only and back APPLY-ON:

DGMGRL> EDIT DATABASE 'db12c' SET STATE='READ-ONLY';
Succeeded.
DGMGRL> show database db12c

Database - db12c

 Role: PHYSICAL STANDBY
 Intended State: READ-ONLY
<<OUTPUT TRIMMED>>
Database Status:
SUCCESS

To change back:

DGMGRL> shutdown 
DGMGRL> startup mount;
DGMGRL> show database db12c

Database - db12c
 Role: PHYSICAL STANDBY
 Intended State: OFFLINE
  <<OUTPUT TRIMMED>>

DGMGRL> EDIT DATABASE DB12C SET STATE = APPLY-ON;
Succeeded.
DGMGRL> show database db12c

Database - db12c

 Role: PHYSICAL STANDBY
 Intended State: APPLY-ON
 <<OUTPUT TRIMMED>>

================================
LOGICAL STANDBY COMMANDS =======
================================

To Restart SQL apply on logical standby

SQL> ALTER DATABASE START LOGICAL STANDBY APPLY IMMEDIATE;
To Stop SQL apply on logical standby

SQL> ALTER DATABASE STOP LOGICAL STANDBY APPLY;
Run the following SQL against the logical standby to start real-time SQL apply if the SQL apply failed with an error, and you are 100% certain that the transaction is safe to skip

SQL> ALTER DATABASE START LOGICAL STANDBY APPLY IMMEDIATE SKIP FAILED TRANSACTION;
To see unsupported tables for logical standby:

SQL> SELECT * FROM DBA_LOGSTDBY_UNSUPPORTED_TABLE ORDER BY OWNER, TABLE_NAME;
To know which archive log sequences are at what stage for logical standby?

SQL> SELECT 'RESTART' "TYPE",
 P.RESTART_SCN "SCN",
 TO_CHAR (P.RESTART_TIME, 'yyyy/mm/dd hh24:mi:ss') "TIME",
 L.SEQUENCE# "SEQ#"
 FROM V$LOGSTDBY_PROGRESS P, DBA_LOGSTDBY_LOG L
 WHERE P.RESTART_SCN >= L.FIRST_CHANGE# AND P.RESTART_SCN < L.NEXT_CHANGE#
UNION
SELECT 'RESTART',
 P.RESTART_SCN,
 TO_CHAR (P.RESTART_TIME, 'yyyy/mm/dd hh24:mi:ss'),
 L.SEQUENCE#
 FROM V$LOGSTDBY_PROGRESS P, V$STANDBY_LOG L
 WHERE P.RESTART_SCN >= L.FIRST_CHANGE# AND P.LATEST_SCN <= L.LAST_CHANGE#
UNION
SELECT 'APPLIED',
 P.APPLIED_SCN,
 TO_CHAR (P.APPLIED_TIME, 'yyyy/mm/dd hh24:mi:ss'),
 L.SEQUENCE#
 FROM V$LOGSTDBY_PROGRESS P, DBA_LOGSTDBY_LOG L
 WHERE P.APPLIED_SCN >= L.FIRST_CHANGE# AND P.APPLIED_SCN < L.NEXT_CHANGE#
UNION
SELECT 'APPLIED',
 P.APPLIED_SCN,
 TO_CHAR (P.APPLIED_TIME, 'yyyy/mm/dd hh24:mi:ss'),
 L.SEQUENCE#
 FROM V$LOGSTDBY_PROGRESS P, V$STANDBY_LOG L
 WHERE P.APPLIED_SCN >= L.FIRST_CHANGE# AND P.LATEST_SCN <= L.LAST_CHANGE#
UNION
SELECT 'MINING',
 P.MINING_SCN,
 TO_CHAR (P.MINING_TIME, 'yyyy/mm/dd hh24:mi:ss'),
 L.SEQUENCE#
 FROM V$LOGSTDBY_PROGRESS P, DBA_LOGSTDBY_LOG L
 WHERE P.MINING_SCN >= L.FIRST_CHANGE# AND P.MINING_SCN < L.NEXT_CHANGE#
UNION
SELECT 'MINING',
 P.MINING_SCN,
 TO_CHAR (P.MINING_TIME, 'yyyy/mm/dd hh24:mi:ss'),
 L.SEQUENCE#
 FROM V$LOGSTDBY_PROGRESS P, V$STANDBY_LOG L
 WHERE P.MINING_SCN >= L.FIRST_CHANGE# AND P.LATEST_SCN <= L.LAST_CHANGE#
UNION
SELECT 'SHIPPED',
 P.LATEST_SCN,
 TO_CHAR (P.LATEST_TIME, 'yyyy/mm/dd hh24:mi:ss'),
 L.SEQUENCE#
 FROM V$LOGSTDBY_PROGRESS P, DBA_LOGSTDBY_LOG L
 WHERE P.LATEST_SCN >= L.FIRST_CHANGE# AND P.LATEST_SCN < L.NEXT_CHANGE#
UNION
SELECT 'SHIPPED',
 P.LATEST_SCN,
 TO_CHAR (P.LATEST_TIME, 'yyyy/mm/dd hh24:mi:ss'),
 L.SEQUENCE#
 FROM V$LOGSTDBY_PROGRESS P, V$STANDBY_LOG L
 WHERE P.LATEST_SCN >= L.FIRST_CHANGE# AND P.LATEST_SCN <= L.LAST_CHANGE#;
To know is the SQL Apply up to date

SQL> SELECT TO_CHAR(LATEST_TIME,'yyyy/mm/dd hh24:mi:ss') "LATEST_TIME", 
TO_CHAR(APPLIED_TIME,'yyyy/mm/dd hh24:mi:ss') "APPLIED_TIME", 
APPLIED_SCN, LATEST_SCN 
FROM V$LOGSTDBY_PROGRESS;
To know is the Logical standby applying changes? Run the following SQL against the Logical standby database:

SQL> SELECT REALTIME_APPLY, STATE FROM V$LOGSTDBY_STATE;
If the value of STATE is “NULL” or “SQL APPLY NOT ON” then the Sql Apply is not running.The value of REALTIME_APPLY should be Y to allow for real time apply from the standby redo logs. To know what major Sql Apply events have occurred, run the following SQL against the Logical standby database:

SQL> SELECT TO_CHAR (EVENT_TIME, 'YYYY/MM/DD HH24:MI:SS') "EVENT_TIME",
STATUS, EVENT
FROM DBA_LOGSTDBY_EVENTS
ORDER BY EVENT_TIME;
To know what major Dataguard events have occurred, run the following SQL against the Logical standby database:

SQL> SELECT TO_CHAR (TIMESTAMP, 'yyyy/mm/dd hh24:mi:ss') "TIME",
ERROR_CODE "ERROR", DEST_ID "DEST", MESSAGE
FROM V$DATAGUARD_STATUS
WHERE timestamp > TRUNC (SYSDATE + 6 / 24)
ORDER BY timestamp DESC;


To know where are the archive logs going and are there any achieving issues, run the following SQL against either the logical standby or primary database:

SQL> SELECT DEST_ID "DID",
STATUS, DESTINATION, ARCHIVER, VALID_NOW, VALID_TYPE, VALID_ROLE, ERROR
FROM V$ARCHIVE_DEST
WHERE STATUS <> 'INACTIVE';
