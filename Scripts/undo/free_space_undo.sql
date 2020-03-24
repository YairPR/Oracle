select a.tablespace_name, SIZEMB, USAGEMB, (SIZEMB - USAGEMB) FREEMB
from (select sum(bytes) / 1024 / 1024 SIZEMB, b.tablespace_name
from dba_data_files a, dba_tablespaces b
where a.tablespace_name = b.tablespace_name
and b.contents = 'UNDO'
group by b.tablespace_name) a,
(select c.tablespace_name, sum(bytes) / 1024 / 1024 USAGEMB
from DBA_UNDO_EXTENTS c
where status <> 'EXPIRED'
group by c.tablespace_name) b
where a.tablespace_name = b.tablespace_name;
