select df.tablespace_name, df.file_name, round(df.bytes/1024/1024) totalSizeMB, nvl(round(usedBytes/1024/1024), 0) usedMB, nvl(round(freeBytes/1024/1024), 0) freeMB,
    nvl(round(freeBytes/df.bytes * 100), 0) freePerc, df.autoextensible
from dba_data_files df
    left join (
        select file_id, sum(bytes) usedBytes
        from dba_extents
        group by file_id
    ) ext on df.file_id = ext.file_id
    left join (
        select file_id, sum(bytes) freeBytes
        from dba_free_space
        group by file_id
    ) free on df.file_id = free.file_id
order by df.tablespace_name, df.file_name
/
