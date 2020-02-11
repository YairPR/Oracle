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
