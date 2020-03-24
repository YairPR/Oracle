--- Sesiones que consumen el tablespace TEMP
SET PAUSE ON
SET PAUSE 'Press Return to Continue'
SET PAGESIZE 50
SET LINESIZE 300
 
COLUMN tablespace FORMAT A20
COLUMN temp_use_mb FORMAT A20
COLUMN sid_serial FORMAT A20
COLUMN username FORMAT A20
COLUMN program FORMAT A50
 
SELECT b.tablespace,
       ROUND(((b.blocks*p.value)/1024/1024),2)||' MB' AS temp_use_mb,
       a.inst_id as Instance,
       a.sid||','||a.serial# AS sid_serial,
       NVL(a.username, '(oracle)') AS username,
       a.program,
       a.status,
       a.sql_id
FROM   gv$session a,
       gv$sort_usage b,
       gv$parameter p
WHERE  p.name  = 'db_block_size'
AND    a.saddr = b.session_addr
AND    a.inst_id=b.inst_id
AND    a.inst_id=p.inst_id
ORDER BY b.tablespace, b.blocks desc
/
-------------------------------------------------------------------------

---- Porcentaje de uso tablespace TEMP
set line 1000
SELECT a.tablespace_name,ROUND((c.total_blocks*b.block_size)/1024/1024/1024,2)
"Total Size [GB]",ROUND((a.used_blocks*b.block_size)/1024/1024/1024,2) "Used_size[GB]",
ROUND(((c.total_blocks-a.used_blocks)*b.block_size)/1024/1024/1024,2) "Free_size[GB]",
ROUND((a.max_blocks*b.block_size)/1024/1024/1024,2) "Max_Size_Ever_Used[GB]",            
ROUND((a.max_used_blocks*b.block_size)/1024/1024/1024,2) "MaxSize_ever_Used_by_Sorts[GB]" ,
ROUND((a.used_blocks/c.total_blocks)*100,2) "Used Percentage"
FROM V$sort_segment a,dba_tablespaces b,(SELECT tablespace_name,SUM(blocks)
total_blocks FROM dba_temp_files GROUP by tablespace_name) c
WHERE a.tablespace_name=b.tablespace_name AND a.tablespace_name=c.tablespace_name;

-------------------------------------------------------------------------------------
--- TEMP useado por session
set line 1000
SELECT S.sid || ',' || S.serial# sid_serial, S.username, S.osuser, P.spid, S.module,
P.program, SUM (T.blocks) * TBS.block_size / 1024 / 1024 mb_used, T.tablespace,
COUNT(*) statements
FROM v$sort_usage T, v$session S, dba_tablespaces TBS, v$process P
WHERE T.session_addr = S.saddr
AND S.paddr = P.addr
AND T.tablespace = TBS.tablespace_name
GROUP BY S.sid, S.serial#, S.username, S.osuser, P.spid, S.module,
P.program, TBS.block_size, T.tablespace
ORDER BY sid_serial;
--------------------------------------------------------------------------------
To see top 10 consuming process :
---------------------------------
set line 1000
select * from
(SELECT d.tablespace_name,a.sid,a.serial#,a.program,a.module,a.action,a.username "DB Username",a.osuser,ROUND((b.blocks*d.block_size)/1024/1024,2) "Used MB",c.sql_text
FROM v$session a, v$tempseg_usage b, v$sqlarea c,dba_tablespaces d
WHERE a.saddr = b.session_addr AND c.address= a.sql_address AND c.hash_value = a.sql_hash_value AND d.tablespace_name=b.tablespace ORDER BY b.tablespace, b.blocks DESC)
where rownum <=10;

----------------------------------------------------------------------------------------

--Porcentaje de uso
select (s.tot_used_blocks/f.total_blocks)*100 as "percent used"
from (select sum(used_blocks) tot_used_blocks
from v$sort_segment where tablespace_name='TEMP') s,
(select sum(blocks) total_blocks
from dba_temp_files where tablespace_name='TEMP') f;
------------------------------------------------------------------------------------------------

--To find Sort Segment Usage by a particular User:

SELECT s.username,s.sid,s.serial#,u.tablespace, u.contents, u.extents, u.blocks
FROM v$session s, v$sort_usage u
WHERE s.saddr=u.session_addr
order by u.blocks desc;

--------------------------------------------------------------------------------------------------

-- 10 sesiones ocn mayor uso d etemp

cursor bigtemp_sids is
select * from (
select s.sid,
s.status,
s.sql_hash_value sesshash,
u.SQLHASH sorthash,
s.username,
u.tablespace,
sum(u.blocks*p.value/1024/1024) mbused ,
sum(u.extents) noexts,
nvl(s.module,s.program) proginfo,
floor(last_call_et/3600)||':'||
floor(mod(last_call_et,3600)/60)||':'||
mod(mod(last_call_et,3600),60) lastcallet
from v$sort_usage u,
v$session s,
v$parameter p
where u.session_addr = s.saddr
and p.name = 'db_block_size'
group by s.sid,s.status,s.sql_hash_value,u.sqlhash,s.username,u.tablespace,
nvl(s.module,s.program),
floor(last_call_et/3600)||':'||
floor(mod(last_call_et,3600)/60)||':'||
mod(mod(last_call_et,3600),60)
order by 7 desc,3)
where rownum < 11;

---------------------------------------------------------------------------------------------------
-- información de sesiones que usan temp
select * from (SELECT u.tablespace, s.username, s.sid, s.serial#, s.logon_time, program, u.extents,
((u.blocks*8)/1024) as MB, i.inst_id,i.host_name FROM gv$session s, gv$sort_usage u ,gv$instance i
WHERE s.saddr=u.session_addr and u.inst_id=i.inst_id order by MB DESC) a where rownum<10;
---------------------------------------------------------------------------------------------------

-- Uso de I/O por tablespoace

SELECT SUBSTR(t.name, 1, 50) AS file_name,
       f.phyblkrd AS blocks_read,
       f.phyblkwrt AS blocks_written,
       f.phyblkrd + f.phyblkwrt AS total_io
FROM v$tempstat f,
     v$tempfile t
WHERE t.file# = f.file# ORDER BY f.phyblkrd + f.phyblkwrt DESC;  

--------------------------------------------------------------------------------------------------------------
-- Examine the number of sorts in the system (from instance startup):

SELECT NAME, VALUE FROM V$SYSSTAT WHERE NAME LIKE '%sorts%';

-----------------------------------------------------------------------------------------------------
-- Examine statistics about temporary tablespace blocks:

COL TABLESPACE_NAME FOR A16
SELECT
TABLESPACE_NAME, CURRENT_USERS,
TOTAL_BLOCKS, USED_BLOCKS, FREE_BLOCKS,
MAX_BLOCKS, MAX_USED_BLOCKS, MAX_SORT_BLOCKS
FROM V$SORT_SEGMENT
ORDER BY TABLESPACE_NAME;
-----------------------------------------------------------------------------------------------------------
--Examine statistics about temporary tablespace extents:

SELECT
TABLESPACE_NAME, CURRENT_USERS, EXTENT_SIZE,
TOTAL_EXTENTS, USED_EXTENTS, FREE_EXTENTS,
EXTENT_HITS
FROM V$SORT_SEGMENT
ORDER BY TABLESPACE_NAME;
--------------------------------------------------------------------------------------------------------

--- Execute a query to retrieve the temporary files:

COL NAME FOR A32
SELECT
NAME, STATUS, ENABLED,
BYTES, BLOCKS, BLOCK_SIZE
FROM V$TEMPFILE;

