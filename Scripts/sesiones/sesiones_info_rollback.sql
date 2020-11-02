-- File Name    : https://oracle-base.com/dba/monitoring/session_rollback.sql
-- Description  : Displays rollback information on relevant database sessions.
-- Requirements : Access to the V$ views.
-- -----------------------------------------------------------------------------------
SET LINESIZE 200

COLUMN username FORMAT A15

SELECT s.username,
       s.sid,
       s.serial#,
       t.used_ublk,
       t.used_urec,
       rs.segment_name,
       r.rssize,
       r.status
FROM   v$transaction t,
       v$session s,
       v$rollstat r,
       dba_rollback_segs rs
WHERE  s.saddr = t.ses_addr
AND    t.xidusn = r.usn
AND   rs.segment_id = t.xidusn
ORDER BY t.used_ublk DESC;


USERNAME               SID    SERIAL#  USED_UBLK  USED_UREC SEGMENT_NAME                       RSSIZE STATUS
--------------- ---------- ---------- ---------- ---------- ------------------------------ ---------- ---------------
ACSELX                4051      58869    1760247  104237008 _SYSSMU588_3415606904$         2115092480 ONLINE
DT_AE_ACR             3519      64647      27261    1304498 _SYSSMU585_672923105$           226615296 ONLINE
ACSELX                4959      30527       6238     221456 _SYSSMU584_3617035736$          971104256 ONLINE
XT0802                2613       2247        336      28707 _SYSSMU1250_79114122$           159375360 ONLINE
TKONG                 2462      16263         33       2530 _SYSSMU935_809469452$          2118246400 ONLINE
XT3296                5522      26603         20       1640 _SYSSMU1202_3552909280$         388096000 ONLINE
DS_SOA_ACSELX         1626      27801          3         91 _SYSSMU1217_1796810315$         330424320 ONLINE
DS_SOA_ACSELX         3940      29847          3         73 _SYSSMU936_12446390$            308404224 ONLINE
SYS                   1267      52639          1          2 _SYSSMU954_562159511$           647094272 ONLINE
ELOPEZG               1173      25357          1          1 _SYSSMU1245_4192339473$         326230016 ONLINE
IBM_NNICHOP           4687      56143          1          1 _SYSSMU913_2035313873$          247586816 ONLINE
ACSELX                 184      51965          1          1 _SYSSMU582_3051114983$          230809600 ONLINE
JDELGADOB             5499      24169          1          1 _SYSSMU885_304899858$           435281920 ONLINE
MARVERA               1235      21065          1          1 _SYSSMU1242_1924130801$         330096640 ONLINE

14 rows selected.

