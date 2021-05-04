set linesize 200
set pagesize 1024
column name format a30
col "Size (M)" format a15
col "Free (MB)" format a15
col "Free %" format a15
col "Used %" format a15
SELECT  d.status "Status",
d.tablespace_name "Name",
d.contents "Type",
d.extent_management "Extent Management",
TO_CHAR(NVL(a.bytes / 1024 / 1024, 0),'99G999G990D900') "Size (M)",
TO_CHAR(NVL(NVL(f.bytes, 0), 0)/1024/1024 ,'99G999G990D900') "Free (MB)",
TO_CHAR(NVL((NVL(f.bytes, 0)) / a.bytes * 100, 0), '990D00') "Free %" ,
TO_CHAR(100-NVL((NVL(f.bytes, 0)) / a.bytes * 100, 0), '990D00') "Used %",
decode(sign(95 - (100-NVL((NVL(f.bytes, 0)) / a.bytes * 100, 0))), -1,'ALERTA!!','     ') "Observacion"
FROM sys.dba_tablespaces d,
( select tablespace_name, sum(bytes) bytes
from dba_data_files group by tablespace_name) a,
(select tablespace_name, sum(bytes) bytes
from dba_free_space group by tablespace_name) f
WHERE d.tablespace_name = a.tablespace_name(+) AND
d.tablespace_name = f.tablespace_name(+) AND
NOT (d.extent_management like 'LOCAL' AND
d.contents like 'TEMPORARY')
UNION ALL
SELECT d.status "Status",
d.tablespace_name "Name",
d.contents "Type",
d.extent_management "Extent Management",
TO_CHAR(NVL(a.bytes / 1024 / 1024, 0),'99G999G990D900') "Size (M)",
TO_CHAR(NVL((a.bytes-t.bytes), a.bytes)/1024/1024,'99G999G990D900') "Free (MB)",
TO_CHAR(NVL((a.bytes-t.bytes) / a.bytes * 100, 100), '990D00') "Free %" ,
TO_CHAR(100 - NVL((a.bytes-t.bytes) / a.bytes * 100, 100), '990D00') "Used %" ,
decode(sign( 95 - (100 - NVL((a.bytes-t.bytes) / a.bytes * 100, 100))), -1 ,'ALERTA!!','      ') "Observaciones"
FROM sys.dba_tablespaces d,
(select tablespace_name, sum(bytes) bytes
from dba_temp_files group by tablespace_name) a,
(select tablespace_name, sum(bytes_cached) bytes
from gv$temp_extent_pool group by tablespace_name) t
WHERE d.tablespace_name = a.tablespace_name(+) AND
d.tablespace_name = t.tablespace_name(+) AND
d.extent_management like 'LOCAL' AND
d.contents like 'TEMPORARY'
order by 8 desc;
       
       
       Status    Name                           Type      Extent Man Size (M)        Free (MB)       Free %          Used %          Observac
--------- ------------------------------ --------- ---------- --------------- --------------- --------------- --------------- --------
ONLINE    TEMP                           TEMPORARY LOCAL          318,460.969         745.969    0.23           99.77         ALERTA!!
ONLINE    INDX_PROD_TRANS_BIG            PERMANENT LOCAL        4,473,329.969      39,200.000    0.88           99.12         ALERTA!!
ONLINE    INDX_PROD_NOTRANS_BIG          PERMANENT LOCAL        2,464,089.984      25,600.000    1.04           98.96         ALERTA!!
ONLINE    DATA_PROD_TRANS_BIG            PERMANENT LOCAL        2,460,870.953      27,680.000    1.12           98.88         ALERTA!!
ONLINE    TBSI_PROD_SMA                  PERMANENT LOCAL          856,767.719      13,869.219    1.62           98.38         ALERTA!!
ONLINE    DATA_PROD_SSD_BIG              PERMANENT LOCAL          913,347.984      18,880.000    2.07           97.93         ALERTA!!
ONLINE    TBSD_PROD_LOGMNR               PERMANENT LOCAL          321,586.922       8,677.625    2.70           97.30         ALERTA!!
ONLINE    TBSD_EVENTUAL_NOR              PERMANENT LOCAL        2,385,123.391      64,770.000    2.72           97.28         ALERTA!!
ONLINE    DATA_PROD_NOTRANS_BIG          PERMANENT LOCAL        2,256,374.953      65,920.000    2.92           97.08         ALERTA!!
ONLINE    INDX_PROD_TRANS_MED            PERMANENT LOCAL        1,833,829.625      55,820.000    3.04           96.96         ALERTA!!
ONLINE    TBSD_NORMAL_NOR                PERMANENT LOCAL          694,804.984      26,160.000    3.77           96.23         ALERTA!!
ONLINE    DATA_PROD_TRANS_MED            PERMANENT LOCAL          909,184.844      35,455.000    3.90           96.10         ALERTA!!
ONLINE    TBSD_PROD_SMA                  PERMANENT LOCAL          510,975.781      21,616.406    4.23           95.77         ALERTA!!
ONLINE    INDX_PROD_NOTRANS_MED          PERMANENT LOCAL          893,320.703      42,880.000    4.80           95.20         ALERTA!!
ONLINE    DATA_PROD_NOTRANS_MED          PERMANENT LOCAL          945,828.844      46,270.000    4.89           95.11         ALERTA!!
ONLINE    TBSD_OTHERS_BIG                PERMANENT LOCAL          529,720.000      38,400.000    7.25           92.75
ONLINE    TBSD_OTHERS_MED                PERMANENT LOCAL          295,467.000      29,705.000   10.05           89.95
ONLINE    TBSD_MCRITICO_ESP              PERMANENT LOCAL          926,853.000      97,440.000   10.51           89.49
ONLINE    TBSD_PROD_MED                  PERMANENT LOCAL          393,127.969      44,315.000   11.27           88.73
ONLINE    TEMP_PROD_NOTRANS_BIG          TEMPORARY LOCAL          217,082.000      28,502.000   13.13           86.87
ONLINE    TBSD_MCRITICO_NOR              PERMANENT LOCAL          211,480.000      28,305.000   13.38           86.62
ONLINE    TBSD_EVENTUAL_EBIG             PERMANENT LOCAL          245,191.000      33,280.000   13.57           86.43
ONLINE    TBSI_OTHERS_SMA                PERMANENT LOCAL           30,844.125       5,382.031   17.45           82.55
ONLINE    INDX_PROD_SSD_BIG              PERMANENT LOCAL          106,396.000      19,520.000   18.35           81.65
ONLINE    TBSI_WEB_BIG                   PERMANENT LOCAL           30,700.000       5,760.000   18.76           81.24

