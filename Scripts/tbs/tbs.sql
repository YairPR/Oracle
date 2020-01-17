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
