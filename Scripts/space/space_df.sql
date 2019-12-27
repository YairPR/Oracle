--9i

undef tbsp
col file_name format a40
 select file_id,
        file_name,
        ((sum(bytes)/1024)/1024) mbytes,
        AUTOEXTENSIBLE,
        (sum(MAXBYTES)/1024)/1024 max_mb,
        (sum(increment_by)/1024)/1024 increment_mb
    from dba_data_files
    where tablespace_name=upper('&tbsp')
   group by file_id,file_name,AUTOEXTENSIBLE
order by file_id
/
