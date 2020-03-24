--https://oracle-base.com/articles/misc/reclaiming-unused-space

set line 200
set verify off;
col cmd format A120;
undef DB_BLOCK_SIZE
undef ts_name

PROMPT

PROMPT --El DB_BLOCK_SIZE se pone en bytes , en vez de 8 se pone 8192

PROMPT

select bytes/1024/1024 real_size,ceil( (nvl(hwm,1)*&&DB_BLOCK_SIZE)/1024/1024 ) shrinked_size,
bytes/1024/1024-ceil( (nvl(hwm,1)*&&DB_BLOCK_SIZE)/1024/1024 ) released_size
,'alter database datafile '|| ''''||file_name||'''' || ' resize ' || ceil( (nvl(hwm,1)*&&DB_BLOCK_SIZE)/1024/1024 ) || 'm;' cmd
from
dba_data_files a,
( select file_id, max(block_id+blocks-1) hwm from dba_extents group by file_id ) b
where
tablespace_name=upper('&ts_name')
and a.file_id = b.file_id(+)
and ceil(blocks*&&DB_BLOCK_SIZE/1024/1024)- ceil((nvl(hwm,1)* &&DB_BLOCK_SIZE)/1024/1024 ) > 0
and a.file_id like '&file_id';
