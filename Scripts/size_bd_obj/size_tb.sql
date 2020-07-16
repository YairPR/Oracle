For oracle table size in MB

select
owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024,2) as "Object Size (Mb)"
, tablespace_name as "Tablespace"
from dba_segments
where segment_name='&table_name';

For oracle table size in GB

select
owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024/1024,2) as "Object Size (GB)"
, tablespace_name as "Tablespace"
from dba_segments
where segment_name='&tab_name';

Top 10 big tables in Particular schema

select * from (select
owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024/1024,2) as "Object Size (Mb)"
, tablespace_name as "Tablespace"
from dba_segments
where owner=’<schema>’  and segment_type='TABLE' order by 4 desc)  where rownum < 11;
Top 10 big tables in Particular tablespace

select * from (select
owner as "Schema"
, segment_name as "Object Name"
, segment_type as "Object Type"
, round(bytes/1024/1024/1024,2) as "Object Size (Mb)"
, tablespace_name as "Tablespace"
from dba_segments
where tablespace_name =’<tablespace name>' and segment_name='TABLE' order by 4 desc ) where rownum <11;
