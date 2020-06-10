select * from (select owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024/1024,2) as "Object Size (Mb)"
, tablespace_name as "Tablespace"
from dba_segments
where tablespace_name ='&tbsname' 
and segment_name='TABLE' order by 4 desc ) 
where rownum < 11
/
