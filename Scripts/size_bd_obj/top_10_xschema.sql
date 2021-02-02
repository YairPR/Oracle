select * from (select
owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024/1024,2) as "Object Size (Mb)"
, tablespace_name as "Tablespace"
from dba_segments
where owner='<schema>'  and segment_type='TABLE' order by 4 desc)  where rownum < 11;
