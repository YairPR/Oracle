--http://oracle-solutions.com/tablespace-temp/

--To check instance-wise total allocated, total used TEMP for both rac and non-rac

set lines 152 
col FreeSpaceGB format 999.999
col UsedSpaceGB format 999.999
col TotalSpaceGB format 999.999
col host_name format a30
col tablespace_name format a30
select tablespace_name,
(free_blocks*8)/1024/1024 FreeSpaceGB,
(used_blocks*8)/1024/1024 UsedSpaceGB,
(total_blocks*8)/1024/1024 TotalSpaceGB,
i.instance_name,i.host_name
from gv$sort_segment ss,gv$instance i where ss.tablespace_name in (select tablespace_name from dba_tablespaces where contents='TEMPORARY') and
i.inst_id=ss.inst_id;

Total Used and Total Free Blocks

select inst_id, tablespace_name, total_blocks, used_blocks, free_blocks from gv$sort_segment;

select inst_id, tablespace_name, total_blocks, used_blocks, free_blocks from gv$sort_segment;

Temporary Tablespace groups

SELECT * FROM DATABASE_PROPERTIES where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';

SELECT * FROM DATABASE_PROPERTIES where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';

select tablespace_name,contents from dba_tablespaces where tablespace_name like '%TEMP%';

select tablespace_name,contents from dba_tablespaces where tablespace_name like '%TEMP%';

select * from dba_tablespace_groups;

select * from dba_tablespace_groups;

Block wise Check

select TABLESPACE_NAME, TOTAL_BLOCKS, USED_BLOCKS, MAX_USED_BLOCKS, MAX_SORT_BLOCKS, FREE_BLOCKS from V$SORT_SEGMENT;

select TABLESPACE_NAME, TOTAL_BLOCKS, USED_BLOCKS, MAX_USED_BLOCKS, MAX_SORT_BLOCKS, FREE_BLOCKS from V$SORT_SEGMENT;

select sum(free_blocks) from gv$sort_segment where tablespace_name = 'TEMP';

select sum(free_blocks) from gv$sort_segment where tablespace_name = 'TEMP';

To Check Percentage Usage of Temp Tablespace
select (s.tot_used_blocks/f.total_blocks)*100 as "percent used"
from (select sum(used_blocks) tot_used_blocks
from v$sort_segment where tablespace_name='TEMP') s,
(select sum(blocks) total_blocks
from dba_temp_files where tablespace_name='TEMP') f;

select (s.tot_used_blocks/f.total_blocks)*100 as "percent used"
from (select sum(used_blocks) tot_used_blocks
from v$sort_segment where tablespace_name='TEMP') s,
(select sum(blocks) total_blocks
from dba_temp_files where tablespace_name='TEMP') f;

To check Used Extents ,Free Extents available in Temp Tablespace

SELECT tablespace_name, extent_size, total_extents, used_extents,free_extents, max_used_size FROM v$sort_segment;

SELECT tablespace_name, extent_size, total_extents, used_extents,free_extents, max_used_size FROM v$sort_segment;

Additional checks

select distinct(temporary_tablespace) from dba_users;

select distinct(temporary_tablespace) from dba_users;

select username,default_tablespace,temporary_tablespace from dba_users order by temporary_tablespace;

select username,default_tablespace,temporary_tablespace from dba_users order by temporary_tablespace;

SELECT * FROM DATABASE_PROPERTIES where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';

SELECT * FROM DATABASE_PROPERTIES where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';

Changing the default temporary Tablespace

alter database default temporary tablespace TEMP;

alter database default temporary tablespace TEMP;
To add tempfile to Temp Tablespace

alter tablespace temp add tempfile '/u01/oradata/temp02.dbf' size 5G autoextend on maxsize unlimited;

alter tablespace temp add tempfile '/u01/oradata/temp02.dbf' size 5G autoextend on maxsize unlimited;
To resize the tempfile in Temp Tablespace

alter database tempfile '/u01/oradata/temp01.dbf' resize 250M;

alter database tempfile '/u01/oradata/temp01.dbf' resize 250M;

alter database tempfile '/u01/oradata//temp01.dbf' autoextend on maxsize 1800M;

alter database tempfile '/u01/oradata//temp01.dbf' autoextend on maxsize 1800M;

alter tablespace TEMP add tempfile '/u01/oradata/temp01.dbf' size 1800m reuse;

alter tablespace TEMP add tempfile '/u01/oradata/temp01.dbf' size 1800m reuse;

To find Sort Segment Usage by Users
select username,sum(extents) "Extents",sum(blocks) "Block"
from v$sort_usage
group by username;

select username,sum(extents) "Extents",sum(blocks) "Block"
from v$sort_usage
group by username;

To find Sort Segment Usage by a particular User
SELECT s.username,s.sid,s.serial#,u.tablespace, u.contents, u.extents, u.blocks
FROM v$session s, v$sort_usage u
WHERE s.saddr=u.session_addr
order by u.blocks desc;

SELECT s.username,s.sid,s.serial#,u.tablespace, u.contents, u.extents, u.blocks
FROM v$session s, v$sort_usage u
WHERE s.saddr=u.session_addr
order by u.blocks desc;
To find Total Free space in Temp Tablespace
select 'FreeSpace ' || (free_blocks*8)/1024/1024 ||' GB' from v$sort_segment where tablespace_name='TEMP';

select 'FreeSpace ' || (free_blocks*8)/1024/1024 ||' GB' from v$sort_segment where tablespace_name='TEMP';

select tablespace_name , (free_blocks*8)/1024/1024 FreeSpaceInGB,
(used_blocks*8)/1024/1024 UsedSpaceInGB,
(total_blocks*8)/1024/1024 TotalSpaceInGB
from v$sort_segment where tablespace_name like '%TEMP%';

select tablespace_name , (free_blocks*8)/1024/1024 FreeSpaceInGB,
(used_blocks*8)/1024/1024 UsedSpaceInGB,
(total_blocks*8)/1024/1024 TotalSpaceInGB
from v$sort_segment where tablespace_name like '%TEMP%';

To list all tempfiles of Temp Tablespace

col file_name for a45
select tablespace_name,file_name,bytes/1024/1024,maxbytes/1024/1024,autoextensible from dba_temp_files order by file_name;

col file_name for a45
select tablespace_name,file_name,bytes/1024/1024,maxbytes/1024/1024,autoextensible from dba_temp_files order by file_name;

SQL>
SELECT d.tablespace_name tablespace , d.file_name filename, d.file_id fl_id, d.bytes/1024/1024
size_m
, NVL(t.bytes_cached/1024/1024, 0) used_m, TRUNC((t.bytes_cached / d.bytes) * 100) pct_used
FROM
sys.dba_temp_files d, v$temp_extent_pool t, v$tempfile v
WHERE (t.file_id (+)= d.file_id)
AND (d.file_id = v.file#);

SELECT d.tablespace_name tablespace , d.file_name filename, d.file_id fl_id, d.bytes/1024/1024
size_m
, NVL(t.bytes_cached/1024/1024, 0) used_m, TRUNC((t.bytes_cached / d.bytes) * 100) pct_used
FROM
sys.dba_temp_files d, v$temp_extent_pool t, v$tempfile v
WHERE (t.file_id (+)= d.file_id)
AND (d.file_id = v.file#);
To find Total Space Allocated for Temp Tablespace

select 'TotalSpace ' || (sum(blocks)*8)/1024/1024 ||' GB' from dba_temp_files where tablespace_name='TEMP';

select 'TotalSpace ' || (sum(blocks)*8)/1024/1024 ||' GB' from dba_temp_files where tablespace_name='TEMP';
Displays the amount of IO for each tempfile

SQL>
SELECT SUBSTR(t.name,1,50) AS file_name, f.phyblkrd AS blocks_read, f.phyblkwrt AS blocks_written,
f.phyblkrd + f.phyblkwrt AS total_io
FROM v$tempstat f,v$tempfile t
WHERE t.file# = f.file#
ORDER BY f.phyblkrd + f.phyblkwrt DESC;

SELECT SUBSTR(t.name,1,50) AS file_name, f.phyblkrd AS blocks_read, f.phyblkwrt AS blocks_written,
f.phyblkrd + f.phyblkwrt AS total_io
FROM v$tempstat f,v$tempfile t
WHERE t.file# = f.file#
ORDER BY f.phyblkrd + f.phyblkwrt DESC;

select * from (SELECT u.tablespace, s.username, s.sid, s.serial#, s.logon_time, program, u.extents, ((u.blocks*8)/1024) as MB,
i.inst_id,i.host_name
FROM gv$session s, gv$sort_usage u ,gv$instance i
WHERE s.saddr=u.session_addr and u.inst_id=i.inst_id order by MB DESC) a where rownum<10;

select * from (SELECT u.tablespace, s.username, s.sid, s.serial#, s.logon_time, program, u.extents, ((u.blocks*8)/1024) as MB,
i.inst_id,i.host_name
FROM gv$session s, gv$sort_usage u ,gv$instance i
WHERE s.saddr=u.session_addr and u.inst_id=i.inst_id order by MB DESC) a where rownum<10;
