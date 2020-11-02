-- -----------------------------------------------------------------------------------
-- File Name    : https://oracle-base.com/dba/monitoring/top_sessions.sql
-- Author       : Tim Hall
-- Description  : Displays information on all database sessions ordered by executions.
-- Requirements : Access to the V$ views.
-- Call Syntax  : @top_sessions.sql (reads, execs or cpu)
-- Last Modified: 21/02/2005
-- -----------------------------------------------------------------------------------
SET LINESIZE 500
SET PAGESIZE 1000
SET VERIFY OFF

COLUMN username FORMAT A15
COLUMN machine FORMAT A25
COLUMN logon_time FORMAT A20

SELECT NVL(a.username, '(oracle)') AS username,
       a.osuser,
       a.sid,
       a.serial#,
       c.value AS &1,
       a.lockwait,
       a.status,
       a.module,
       a.machine,
       a.program,
       TO_CHAR(a.logon_Time,'DD-MON-YYYY HH24:MI:SS') AS logon_time
FROM   v$session a,
       v$sesstat c,
       v$statname d
WHERE  a.sid        = c.sid
AND    c.statistic# = d.statistic#
AND    d.name       = DECODE(UPPER('&1'), 'READS', 'session logical reads',
                                          'EXECS', 'execute count',
                                          'CPU',   'CPU used by this session',
                                                   'CPU used by this session')
ORDER BY c.value DESC;

SET PAGESIZE 14

USERNAME        OSUSER                                SID    SERIAL#      VALUE LOCKWAIT         STATUS   MODULE                                                           MACHINE                   PROGRAM                                          LOGON_TIME
--------------- ------------------------------ ---------- ---------- ---------- ---------------- -------- ---------------------------------------------------------------- ------------------------- ------------------------------------------------ --------------------
IBM_NNICHOP     ibm_nnichop                          4687      56143    9261416                  ACTIVE   PL/SQL Developer                                                 RIMAC\RSDCPVDI094                                                          28-OCT-2020 21:26:01
DT_AE_ACR       dsadm                                3519      64647    4324967                  ACTIVE   phantom@rsdcpds01 (TNS V1-V3)                                    rsdcpds01                 phantom@rsdcpds01 (TNS V1-V3)                    28-OCT-2020 02:32:14
(oracle)        oracle                                601          1     867247                  ACTIVE                                                                    rsdcpdbprod01             oracle@rsdcpdbprod01 (LMS7)                      18-OCT-2020 05:15:32
(oracle)        oracle                                541          1     861675                  ACTIVE                                                                    rsdcpdbprod01             oracle@rsdcpdbprod01 (LMS5)                      18-OCT-2020 05:15:32
(oracle)        oracle                                571          1     860796                  ACTIVE                                                                    rsdcpdbprod01             oracle@rsdcpdbprod01 (LMS6)  
