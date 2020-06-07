set linesize 200 trimspool on pagesize 50
col tablespace_name format a25
col MB_ALLOC format 99999999.99
col MB_FREE format 99999999.99
col MB_USED format 99999999.99
col "FREE_%" format 99999999.99
col "USED_%" format 99999999.99
col "MAX_MB" format 99999999.99
WITH CONSULTA AS (
select  a.tablespace_name,
       round(a.bytes_alloc / 1024 / 1024 /1024, 2) GB_alloc,
       round(nvl(b.bytes_free, 0) / 1024 / 1024 /1024, 2) GB_free,
       round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024 /1024, 2) GB_used,
       round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) "FREE_%",
       100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2) "USED_%",
       round(maxbytes/1024/1024/1024,2) Max_GB
from  ( select  f.tablespace_name,
               sum(f.bytes) bytes_alloc,
               sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
        from dba_data_files f
        group by tablespace_name) a,
      ( select  f.tablespace_name,
               sum(f.bytes)  bytes_free
        from dba_free_space f
        group by tablespace_name) b
where a.tablespace_name = b.tablespace_name (+)
union all
select h.tablespace_name,
       round(sum(h.bytes_free + h.bytes_used) / 1024/1024/1024, 2) GB_alloc,
       round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1024/1024/1024, 2) GB_free,
       round(sum(nvl(p.bytes_used, 0))/ 1024/1024/1024, 2) GB_used,
       round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2) Pct_Free,
       100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2) pct_used,
       round(sum(f.maxbytes) / 1024/1024/1024, 2) max
from   sys.v_$TEMP_SPACE_HEADER h, sys.v_$Temp_extent_pool p, dba_temp_files f
where  p.file_id(+) = h.file_id
and    p.tablespace_name(+) = h.tablespace_name
and    f.file_id = h.file_id
and    f.tablespace_name = h.tablespace_name
group by h.tablespace_name
ORDER BY 6 desc)
select * from CONSULTA
order by 1;


