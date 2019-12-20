/*
@Author: E. Yair Purisaca R.
@Email: eddiepurisaca@gmail.com
DATABASE SIZE*/

-- Phisical total
SELECT floor(sum(bytes)/1024/1024/1024) AS "Tamaño(GB)" 
FROM dba_data_files;

-- In Using
SELECT floor(sum(bytes)/1024/1024/1024) AS "Tamaño(GB)" 
FROM dba_segments;

-- Size for schema
SELECT owner, floor(sum(bytes)/1024/1024) Size_MB 
FROM dba_segments
WHERE owner IN ('SCHEMA')  
GROUP  BY owner
ORDER BY 2 DESC;


---- get size

col "Database Size" format a20
col "Free space" format a20
col "Used space" format a20
select round(sum(used.bytes) / 1024 / 1024 / 1024 ) || ' GB' "Database Size"
, round(sum(used.bytes) / 1024 / 1024 / 1024 ) -
round(free.p / 1024 / 1024 / 1024) || ' GB' "Used space"
, round(free.p / 1024 / 1024 / 1024) || ' GB' "Free space"
from (select bytes
from v$datafile
union all
select bytes
from v$tempfile
union all
select bytes
from v$log) used
, (select sum(bytes) as p
from dba_free_space) free
group by free.p
/
 

