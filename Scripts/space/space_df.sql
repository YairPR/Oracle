--9i

undef tbsp
col file_name format a70
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


*****************************************************************************


SELECT df.file_id,
       df.file_name,
       ROUND(df.bytes/1024/1024) AS mbytes,
       df.autoextensible AS aut,
       ROUND(df.maxbytes/1024/1024) AS max_mb,
       ROUND(df.increment_by * bs.value / 1024 / 1024, 6) AS increment_mb,
       CASE WHEN ts.bigfile = 'YES' THEN 'YES' ELSE 'NO' END AS big,
       /* % FREE REAL */
       CASE
           WHEN df.autoextensible = 'YES' AND df.maxbytes > 0 THEN
                ROUND( (df.maxbytes - df.bytes) / df.maxbytes * 100 , 2)
           ELSE
                ROUND( (df.bytes - df.bytes) / df.bytes , 2)  -- 0% (no aplica)
       END AS free_percent,
       /* Detectar inconsistencia BYTES > MAXBYTES */
       CASE
           WHEN df.bytes > df.maxbytes AND df.maxbytes > 0 THEN 'INCONSISTENTE'
           ELSE 'OK'
       END AS status
FROM   dba_data_files df
JOIN   dba_tablespaces ts ON df.tablespace_name = ts.tablespace_name
JOIN   v$parameter bs ON bs.name = 'db_block_size'
WHERE  df.tablespace_name = UPPER('&TBSP')
ORDER BY df.file_id;
