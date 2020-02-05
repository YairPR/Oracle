set echo off
set feedback off
set termout off
set pause off
set head on
set lines 100
set pages 500
clear columns
clear computes
set markup html on spool on preformat off entmap on –
head ‘ –
  <title>Redo Log Switch Report</title> –
  <style type=”text/css”> –
    body              {font:9pt Arial,Helvetica,sans-serif; color:black; background:White;} –
    p                 {font:9pt Arial,Helvetica,sans-serif; color:black; background:White;} –
    table,tr,td       {font:9pt Arial,Helvetica,sans-serif; color:Black; background:#C0C0C0; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px;} –
    th                {font:bold 9pt Arial,Helvetica,sans-serif; color:#336699; background:#cccc99; padding:0px 0px 0px 0px;} –
    h1                {font:bold 12pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background-color:White; border-bottom:1px solid #cccc99; margin-top:0pt; margin-bottom:0pt; padding:0px 0px 0px 0px;} –
    h2                {font:bold 10pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background-color:White; margin-top:4pt; margin-bottom:0pt;} –
    a                 {font:9pt Arial,Helvetica,sans-serif; color:#663300; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.link            {font:9pt Arial,Helvetica,sans-serif; color:#663300; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.noLink          {font:9pt Arial,Helvetica,sans-serif; color:#663300; text-decoration: none; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.noLinkBlue      {font:9pt Arial,Helvetica,sans-serif; color:#0000ff; text-decoration: none; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.noLinkDarkBlue  {font:9pt Arial,Helvetica,sans-serif; color:#000099; text-decoration: none; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.noLinkRed       {font:9pt Arial,Helvetica,sans-serif; color:#ff0000; text-decoration: none; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.noLinkDarkRed   {font:9pt Arial,Helvetica,sans-serif; color:#990000; text-decoration: none; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.noLinkGreen     {font:9pt Arial,Helvetica,sans-serif; color:#00ff00; text-decoration: none; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
    a.noLinkDarkGreen {font:9pt Arial,Helvetica,sans-serif; color:#009900; text-decoration: none; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} –
  </style>’ –
body   ‘BGCOLOR=”#C0C0C0″‘ –
table  ‘BORDER=”1″‘
set heading on
prompt Redo Log Switches for a month
CLEAR COLUMNS BREAKS COMPUTES
COLUMN DAY   FORMAT a75              HEADING ‘MM/dd; Time’
COLUMN H00   FORMAT 999,999B         HEADING ’00’
COLUMN H01   FORMAT 999,999B         HEADING ’01’
COLUMN H02   FORMAT 999,999B         HEADING ’02’
COLUMN H03   FORMAT 999,999B         HEADING ’03’
COLUMN H04   FORMAT 999,999B         HEADING ’04’
COLUMN H05   FORMAT 999,999B         HEADING ’05’
COLUMN H06   FORMAT 999,999B         HEADING ’06’
COLUMN H07   FORMAT 999,999B         HEADING ’07’
COLUMN H08   FORMAT 999,999B         HEADING ’08’
COLUMN H09   FORMAT 999,999B         HEADING ’09’
COLUMN H10   FORMAT 999,999B         HEADING ’10’
COLUMN H11   FORMAT 999,999B         HEADING ’11’
COLUMN H12   FORMAT 999,999B         HEADING ’12’
COLUMN H13   FORMAT 999,999B         HEADING ’13’
COLUMN H14   FORMAT 999,999B         HEADING ’14’
COLUMN H15   FORMAT 999,999B         HEADING ’15’
COLUMN H16   FORMAT 999,999B         HEADING ’16’
COLUMN H17   FORMAT 999,999B         HEADING ’17’
COLUMN H18   FORMAT 999,999B         HEADING ’18’
COLUMN H19   FORMAT 999,999B         HEADING ’19’
COLUMN H20   FORMAT 999,999B         HEADING ’20’
COLUMN H21   FORMAT 999,999B         HEADING ’21’
COLUMN H22   FORMAT 999,999B         HEADING ’22’
COLUMN H23   FORMAT 999,999B         HEADING ’23’
COLUMN TOTAL FORMAT 999,999,999      HEADING ‘Total’
break on report
compute  avg LABEL ‘Average:’ sum LABEL ‘Total:’ of total  ON report
SELECT
    SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH:MI:SS’),1,5) || TO_CHAR(first_time, ‘ Dy’) DAY
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’00’,1,0)) H00
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’01’,1,0)) H01
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’02’,1,0)) H02
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’03’,1,0)) H03
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’04’,1,0)) H04
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’05’,1,0)) H05
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’06’,1,0)) H06
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’07’,1,0)) H07
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’08’,1,0)) H08
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’09’,1,0)) H09
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’10’,1,0)) H10
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’11’,1,0)) H11
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’12’,1,0)) H12
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’13’,1,0)) H13
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’14’,1,0)) H14
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’15’,1,0)) H15
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’16’,1,0)) H16
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’17’,1,0)) H17
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’18’,1,0)) H18
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’19’,1,0)) H19
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’20’,1,0)) H20
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’21’,1,0)) H21
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’22’,1,0)) H22
  , SUM(DECODE(SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH24:MI:SS’),10,2),’23’,1,0)) H23
  , COUNT(*)                                                                      TOTAL
FROM
  v$log_history  a
  where trunc(first_time) >= trunc(sysdate)-30
GROUP BY SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH:MI:SS’),1,5) || TO_CHAR(first_time, ‘ Dy’)
order BY SUBSTR(TO_CHAR(first_time, ‘MM/DD/RR HH:MI:SS’),1,5) || TO_CHAR(first_time, ‘ Dy’)
;
spool archive_log_count.html
/
spool off
exit

