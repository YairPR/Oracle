*/
RDBMS Version: 10g.
Script shows following session statistic values:
PGA Memory, in MB;
CPU, used by session;
Hard Parse, %;
Physical read bytes, in MB;
Physical write bytes, in MB;
Redo size, in MB;
Received from client, in MB;
Sent to client, in MB.
*/

SELECT Logon_time,
         (SELECT ROUND (VALUE / 1024 / 1024, 2)
            FROM v$sesstat
           WHERE STATISTIC# = 25 AND v$sesstat.SID = v$session.sid)
            AS "PGA Memory, in MB",
         (SELECT VALUE
            FROM v$sesstat
           WHERE STATISTIC# = 12 AND v$sesstat.SID = v$session.sid)
            AS "CPU, used by session",
         ROUND ( (SELECT VALUE
                    FROM v$sesstat
                   WHERE STATISTIC# = 339 AND v$sesstat.SID = v$session.sid)
                / (SELECT DECODE (VALUE, 0, 1, VALUE)
                     FROM v$sesstat
                    WHERE STATISTIC# = 338 AND v$sesstat.SID = v$session.sid),
                2)
            AS "Hard Parse, %",
         (SELECT ROUND (VALUE / 1024 / 1024, 2)
            FROM v$sesstat
           WHERE STATISTIC# = 58 AND v$sesstat.SID = v$session.sid)
            AS "Physical read bytes, in MB",
         (SELECT ROUND (VALUE / 1024 / 1024, 2)
            FROM v$sesstat
           WHERE STATISTIC# = 66 AND v$sesstat.SID = v$session.sid)
            AS "Physical write bytes, in MB",
         (SELECT ROUND (VALUE / 1024 / 1024, 2)
            FROM v$sesstat
           WHERE STATISTIC# = 139 AND v$sesstat.SID = v$session.sid)
            AS "Redo size, in MB",
         (SELECT ROUND (VALUE / 1024 / 1024, 2)
            FROM v$sesstat
           WHERE STATISTIC# = 344 AND v$sesstat.SID = v$session.sid)
            AS "Received from client, in MB",
         (SELECT ROUND (VALUE / 1024 / 1024, 2)
            FROM v$sesstat
           WHERE STATISTIC# = 343 AND v$sesstat.SID = v$session.sid)
            AS "Sent to client, in MB",
         SID,
         SERIAL#,
         v$session.STATUS,
         PROGRAM,
         USER#,
         USERNAME,
         COMMAND,
         OWNERID,
         OSUSER,
         PROCESS,
         MACHINE,
         OBJECT_NAME
    FROM    v$session
         LEFT OUTER JOIN
            DBA_OBJECTS
         ON v$session.ROW_WAIT_OBJ# = dba_objects.object_ID
   WHERE v$session.LOGON_TIME BETWEEN TRUNC (SYSDATE) AND SYSDATE
         --AND v$session.STATUS = 'ACTIVE'
ORDER BY 5 DESC

/*
Oracle 11g have changed statistac ID’s there for I put the same script for 11g:
*/

SELECT Logon_time,
       (SELECT ROUND (VALUE / 1024 / 1024, 2)
          FROM v$sesstat
         WHERE STATISTIC# = 35 AND v$sesstat.SID = v$session.sid)
          AS "PGA Memory, in MB",
       (SELECT VALUE
          FROM v$sesstat
         WHERE STATISTIC# = 17 AND v$sesstat.SID = v$session.sid)
          AS "CPU, used by session",
       ROUND ( (SELECT VALUE
                  FROM v$sesstat
                 WHERE STATISTIC# = 584 AND v$sesstat.SID = v$session.sid)
              / (SELECT DECODE (VALUE, 0, 1, VALUE)
                   FROM v$sesstat
                  WHERE STATISTIC# = 583 AND v$sesstat.SID = v$session.sid),
              2)
          AS "Hard Parse, %",
       (SELECT ROUND (VALUE / 1024 / 1024, 2)
          FROM v$sesstat
         WHERE STATISTIC# = 83 AND v$sesstat.SID = v$session.sid)
          AS "Physical read bytes, in MB",
       (SELECT ROUND (VALUE / 1024 / 1024, 2)
          FROM v$sesstat
         WHERE STATISTIC# = 96 AND v$sesstat.SID = v$session.sid)
          AS "Physical write bytes, in MB",
       (SELECT ROUND (VALUE / 1024 / 1024, 2)
          FROM v$sesstat
         WHERE STATISTIC# = 185 AND v$sesstat.SID = v$session.sid)
          AS "Redo size, in MB",
       (SELECT ROUND (VALUE / 1024 / 1024, 2)
          FROM v$sesstat
         WHERE STATISTIC# = 590 AND v$sesstat.SID = v$session.sid)
          AS "Received from client, in MB",
       (SELECT ROUND (VALUE / 1024 / 1024, 2)
          FROM v$sesstat
         WHERE STATISTIC# = 589 AND v$sesstat.SID = v$session.sid)
          AS "Sent to client, in MB",
       SID,
       SERIAL#,
       v$session.STATUS,
       PROGRAM,
       USER#,
       USERNAME,
       COMMAND,
       OWNERID,
       OSUSER,
       PROCESS,
       MACHINE,
       OBJECT_NAME
  FROM    v$session
       LEFT OUTER JOIN
          DBA_OBJECTS
       ON v$session.ROW_WAIT_OBJ# = dba_objects.object_ID
 WHERE v$session.LOGON_TIME BETWEEN TRUNC (SYSDATE) AND SYSDATE
       --AND v$session.STATUS = 'ACTIVE'
ORDER BY 5 DESC
