set lines 200 pages 10000
COLUMN DAY   FORMAT a5            HEADING 'MM/dd'
COLUMN H00   FORMAT 999.9B         HEADING '00'
COLUMN H01   FORMAT 999.9B         HEADING '01'
COLUMN H02   FORMAT 999.9B         HEADING '02'
COLUMN H03   FORMAT 999.9B         HEADING '03'
COLUMN H04   FORMAT 999.9B         HEADING '04'
COLUMN H05   FORMAT 999.9B         HEADING '05'
COLUMN H06   FORMAT 999.9B         HEADING '06'
COLUMN H07   FORMAT 999.9B         HEADING '07'
COLUMN H08   FORMAT 999.9B         HEADING '08'
COLUMN H09   FORMAT 999.9B         HEADING '09'
COLUMN H10   FORMAT 999.9B         HEADING '10'
COLUMN H11   FORMAT 999.9B         HEADING '11'
COLUMN H12   FORMAT 999.9B         HEADING '12'
COLUMN H13   FORMAT 999.9B         HEADING '13'
COLUMN H14   FORMAT 999.9B         HEADING '14'
COLUMN H15   FORMAT 999.9B         HEADING '15'
COLUMN H16   FORMAT 999.9B         HEADING '16'
COLUMN H17   FORMAT 999.9B         HEADING '17'
COLUMN H18   FORMAT 999.9B         HEADING '18'
COLUMN H19   FORMAT 999.9B         HEADING '19'
COLUMN H20   FORMAT 999.9B         HEADING '20'
COLUMN H21   FORMAT 999.9B         HEADING '21'
COLUMN H22   FORMAT 999.9B         HEADING '22'
COLUMN H23   FORMAT 999.9B         HEADING '23'
COLUMN TOTAL FORMAT 9999.9      HEADING 'Total'

SELECT
    SUBSTR(TO_CHAR(completion_time, 'MM/DD/RR HH:MI:SS'),1,5) DAY,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'00',blocks*block_size,0))/(1024*1024*1024) H00,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'01',blocks*block_size,0))/(1024*1024*1024) H01,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'02',blocks*block_size,0))/(1024*1024*1024) H02,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'03',blocks*block_size,0))/(1024*1024*1024) H03,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'04',blocks*block_size,0))/(1024*1024*1024) H04,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'05',blocks*block_size,0))/(1024*1024*1024) H05,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'06',blocks*block_size,0))/(1024*1024*1024) H06,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'07',blocks*block_size,0))/(1024*1024*1024) H07,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'08',blocks*block_size,0))/(1024*1024*1024) H08,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'09',blocks*block_size,0))/(1024*1024*1024) H09,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'10',blocks*block_size,0))/(1024*1024*1024) H10,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'11',blocks*block_size,0))/(1024*1024*1024) H11,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'12',blocks*block_size,0))/(1024*1024*1024) H12,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'13',blocks*block_size,0))/(1024*1024*1024) H13,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'14',blocks*block_size,0))/(1024*1024*1024) H14,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'15',blocks*block_size,0))/(1024*1024*1024) H15,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'16',blocks*block_size,0))/(1024*1024*1024) H16,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'17',blocks*block_size,0))/(1024*1024*1024) H17,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'18',blocks*block_size,0))/(1024*1024*1024) H18,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'19',blocks*block_size,0))/(1024*1024*1024) H19,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'20',blocks*block_size,0))/(1024*1024*1024) H20,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'21',blocks*block_size,0))/(1024*1024*1024) H21,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'22',blocks*block_size,0))/(1024*1024*1024) H22,
    SUM(DECODE(TO_CHAR(completion_time, 'HH24'),'23',blocks*block_size,0))/(1024*1024*1024) H23,
    sum(blocks*block_size)/(1024*1024*1024)                                                 TOTAL
FROM v$archived_log
where trunc(completion_time) >= trunc(sysdate)-30
  and dest_id = 1
GROUP BY SUBSTR(TO_CHAR(completion_time, 'MM/DD/RR HH:MI:SS'),1,5)
order BY 1
;
