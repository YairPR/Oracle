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


COL file_name FORMAT a70
COL aut FORMAT a3
COL big FORMAT a3
COL status FORMAT a15
COL free_percent FORMAT 999.99
-- Formato de columnas
COL file_name FORMAT a70
COL aut FORMAT a3
COL big FORMAT a3
COL status FORMAT a15
COL free_percent FORMAT 999.99

SELECT 
       df.file_id,
       df.file_name,
       ROUND(df.bytes/1024/1024) AS mbytes,    
       -- AUTOEXTEND YES/NO
       df.autoextensible AS aut,     
       ROUND(df.maxbytes/1024/1024) AS max_mb,
       -- Incremento en MB
       ROUND(df.increment_by * bs.value / 1024 / 1024, 6) AS increment_mb,
       -- BIGFILE YES/NO
       ts.bigfile AS big,
       -- %FREE_REAL
       CASE
           WHEN df.autoextensible = 'YES' AND df.maxbytes > 0 THEN
                ROUND((df.maxbytes - df.bytes)/df.maxbytes * 100,2)
           ELSE
                ROUND((df.bytes - NVL(s.used_bytes,0))/df.bytes * 100,2)
       END AS free_percent,
       -- Detectar inconsistencias
       CASE
           WHEN df.maxbytes > 0 AND df.bytes > df.maxbytes THEN 'INCONSISTENTE'
           ELSE 'OK'
       END AS status
FROM   dba_data_files df
JOIN   dba_tablespaces ts 
       ON df.tablespace_name = ts.tablespace_name
JOIN   v$parameter bs 
       ON bs.name = 'db_block_size'
-- Subquery para calcular espacio usado por datafiles NO autoextendibles
LEFT JOIN (
    SELECT header_file, tablespace_name, SUM(bytes) AS used_bytes
    FROM dba_segments
    GROUP BY header_file, tablespace_name
) s 
       ON s.tablespace_name = df.tablespace_name
      AND s.header_file = df.file_id
WHERE df.tablespace_name = UPPER('&TBSP')
ORDER BY df.file_id;



