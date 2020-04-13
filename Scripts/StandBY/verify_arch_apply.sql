select max(sequence#) from v$archived_log where applied = 'YES';

Prompt -- Display the log entries in alert log according to Physical Standby Synch
SELECT MESSAGE FROM V$DATAGUARD_STATUS;
Prompt -- Press any key to continue
Pause

Prompt -- Verify background process
SELECT PROCESS, STATUS, THREAD#, SEQUENCE#, BLOCK#, BLOCKS FROM V$MANAGED_STANDBY;
Prompt -- Press any key to continue
Pause

Prompt -- Verify the applied log 

SELECT ARCH.THREAD# "Thread", ARCH.SEQUENCE# "Last Sequence Received", APPL.SEQUENCE# "Last Sequence Applied", (ARCH.SEQUENCE# - APPL.SEQUENCE#) "Difference"
FROM
(SELECT THREAD# ,SEQUENCE# FROM V$ARCHIVED_LOG WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$ARCHIVED_LOG GROUP BY THREAD#)) ARCH,
(SELECT THREAD# ,SEQUENCE# FROM V$LOG_HISTORY WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME) FROM V$LOG_HISTORY GROUP BY THREAD#)) APPL
WHERE
ARCH.THREAD# = APPL.THREAD#
ORDER BY 1;

--------------------------------------------------------------------------------------------------------------------------
--https://dbaclass.com/article/scripts-to-monitor-standby-database/

FIND THE ARCHIVE LAG BETWEEN PRIMARY AND STANDBY:
 
select LOG_ARCHIVED-LOG_APPLIED "LOG_GAP" from
(SELECT MAX(SEQUENCE#) LOG_ARCHIVED
FROM V$ARCHIVED_LOG WHERE DEST_ID=1 AND ARCHIVED='YES'),
(SELECT MAX(SEQUENCE#) LOG_APPLIED
FROM V$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES');
 
 

CHECK THE STATUS OF DIFFERENT PROCESS:
 
SQL> SELECT PROCESS, STATUS, THREAD#, SEQUENCE#, BLOCK#, BLOCKS FROM V$MANAGED_STANDBY ;
 
PROCESS   STATUS          THREAD#  SEQUENCE#     BLOCK#     BLOCKS
--------- ------------ ---------- ---------- ---------- ----------
ARCH      CONNECTED             0          0          0          0
ARCH      CONNECTED             0          0          0          0
ARCH      CONNECTED             0          0          0          0
ARCH      CONNECTED             0          0          0          0
MRP0      WAIT_FOR_LOG          1      53056          0          0
RFS       IDLE                  0          0          0          0
RFS       IDLE                  0          0          0          0
RFS       IDLE                  1      53056      10935          2
RFS       IDLE                  0          0          0          0
 
9 rows selected.
 
 

 
LAST SEQUENCE RECEIVED AND LAST SEQUENCE APPLIED
 
SQL> SELECT al.thrd "Thread", almax "Last Seq Received", lhmax "Last Seq Applied" FROM
  2  (select thread# thrd, MAX(sequence#) almax FROM v$archived_log WHERE resetlogs_change#=(SELECT resetlogs_change#
  3   FROM v$database) GROUP BY thread#) al, (SELECT thread# thrd, MAX(sequence#) lhmax FROM v$log_history
WHERE resetlogs_change#=(SELECT resetlogs_change# FROM v$database) GROUP BY thread#) lh WHERE al.thrd = lh.thrd;  4
 
    Thread Last Seq Received Last Seq Applied
---------- ----------------- ----------------
         1             49482            49482
 
 

CHECK THE MESSAGES/ERRORS IN STNADBY DATABASE:
 
set pagesize 2000
set lines 2000
col MESSAGE for a90
select message,timestamp from V$DATAGUARD_STATUS where timestamp > sysdate - 1/6;
MESSAGE                                                                                    TIMESTAMP
------------------------------------------------------------------------------------------ ---------
RFS[48]: No standby redo logfiles created                                                  05-AUG-15
Media Recovery Log /uv1010/arch/MRSX/arch_MRSX_779539386_1_49481.log                       05-AUG-15
Media Recovery Waiting for thread 1 sequence 49482 (in transit)                            05-AUG-15
RFS[48]: No standby redo logfiles created                                                  05-AUG-15
Media Recovery Log /uv1010/arch/MRSX/arch_MRSX_779539386_1_49482.log                       05-AUG-15
Media Recovery Waiting for thread 1 sequence 49483 (in transit)                            05-AUG-15
 
6 rows selected.
 
 

CHECK THE NUMBER OF ARCHIVES GETTING GENERATING ON HOURLY BASIS:
 
SELECT TO_CHAR(TRUNC(FIRST_TIME),'Mon DD') "DG Date",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'00',1,0)),'9999')      "12AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'01',1,0)),'9999')      "01AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'02',1,0)),'9999')      "02AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'03',1,0)),'9999')      "03AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'04',1,0)),'9999')      "04AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'05',1,0)),'9999')      "05AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'06',1,0)),'9999')      "06AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'07',1,0)),'9999')      "07AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'08',1,0)),'9999')      "08AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'09',1,0)),'9999')      "09AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'10',1,0)),'9999')      "10AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'11',1,0)),'9999')      "11AM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'12',1,0)),'9999')      "12PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'13',1,0)),'9999')      "1PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'14',1,0)),'9999')      "2PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'15',1,0)),'9999')      "3PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'16',1,0)),'9999')      "4PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'17',1,0)),'9999')      "5PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'18',1,0)),'9999')      "6PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'19',1,0)),'9999')      "7PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'20',1,0)),'9999')      "8PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'21',1,0)),'9999')      "9PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'22',1,0)),'9999')      "10PM",
TO_CHAR(SUM(DECODE(TO_CHAR(FIRST_TIME,'HH24'),'23',1,0)),'9999')      "11PM"
FROM V$LOG_HISTORY
GROUP BY TRUNC(FIRST_TIME)
ORDER BY TRUNC(FIRST_TIME) DESC
/
 
