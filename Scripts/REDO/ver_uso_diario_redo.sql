set lines 200 pages 10000
COLUMN Dia   FORMAT a5            HEADING 'MM/dd'
COLUMN H00   FORMAT 9999B         HEADING '00'
COLUMN H01   FORMAT 9999B         HEADING '01'
COLUMN H02   FORMAT 9999B         HEADING '02'
COLUMN H03   FORMAT 9999B         HEADING '03'
COLUMN H04   FORMAT 9999B         HEADING '04'
COLUMN H05   FORMAT 9999B         HEADING '05'
COLUMN H06   FORMAT 9999B         HEADING '06'
COLUMN H07   FORMAT 9999B         HEADING '07'
COLUMN H08   FORMAT 9999B         HEADING '08'
COLUMN H09   FORMAT 9999B         HEADING '09'
COLUMN H10   FORMAT 9999B         HEADING '10'
COLUMN H11   FORMAT 9999B         HEADING '11'
COLUMN H12   FORMAT 9999B         HEADING '12'
COLUMN H13   FORMAT 9999B         HEADING '13'
COLUMN H14   FORMAT 9999B         HEADING '14'
COLUMN H15   FORMAT 9999B         HEADING '15'
COLUMN H16   FORMAT 9999B         HEADING '16'
COLUMN H17   FORMAT 9999B         HEADING '17'
COLUMN H18   FORMAT 9999B         HEADING '18'
COLUMN H19   FORMAT 9999B         HEADING '19'
COLUMN H20   FORMAT 9999B         HEADING '20'
COLUMN H21   FORMAT 9999B         HEADING '21'
COLUMN H22   FORMAT 9999B         HEADING '22'
COLUMN H23   FORMAT 9999B         HEADING '23'
COLUMN TOTAL FORMAT 999,999      HEADING 'Total'
SELECT
    TO_CHAR(first_time, 'MM/DD')                      Dia,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'00',1,0)) H00,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'01',1,0)) H01,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'02',1,0)) H02,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'03',1,0)) H03,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'04',1,0)) H04,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'05',1,0)) H05,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'06',1,0)) H06,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'07',1,0)) H07,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'08',1,0)) H08,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'09',1,0)) H09,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'10',1,0)) H10,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'11',1,0)) H11,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'12',1,0)) H12,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'13',1,0)) H13,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'14',1,0)) H14,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'15',1,0)) H15,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'16',1,0)) H16,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'17',1,0)) H17,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'18',1,0)) H18,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'19',1,0)) H19,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'20',1,0)) H20,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'21',1,0)) H21,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'22',1,0)) H22,
    SUM(DECODE(TO_CHAR(first_time, 'HH24'),'23',1,0)) H23,
    COUNT(*)                                          Total
FROM
  v$log_history  a
  where trunc(first_time) >= trunc(sysdate)-30
GROUP BY TO_CHAR(first_time, 'MM/DD')
order BY 1
;

