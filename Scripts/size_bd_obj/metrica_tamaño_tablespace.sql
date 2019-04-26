/*
@Author: E. Yair Purisaca R.
@Email: eddiepurisaca@gmail.com
Tablespace size using **dba_tablespace_usage_metrics** this view allows us to see
the total space used, based in turn on the space available on the FileSystem.
Example:
Tablespace System has datafile system01.dbf of size 10 GB as MAXSIZE of which
the current size is 5 GB and the extent of 100M grows where the space used is 4.5Gb
so the view dba_tablespace_usage_metrics considers that the Tbalespace is 50%
of its use.
If the query or query on dba_extents is used, this is only about the size of the datafiles
in use so in the example is 5GB the current size and in use of 4.5Gb which would cause
the alert is triggered since it is "used" more than 80%.
dba_tablespace_usage_metrics gives us a more precise metric.*/

SELECT
  a.tablespace_name AS "Nombre Tablespace",
  ROUND((a.used_space * b.block_size) / 1048576, 2) AS "Espacio Usadp (MB)",
  ROUND((a.tablespace_size * b.block_size) / 1048576, 2) AS "Tamaño Tablespace (MB)",
  ROUND(a.used_percent, 2) AS "Used %"
FROM dba_tablespace_usage_metrics a
  JOIN dba_tablespaces b 
  ON a.tablespace_name = b.tablespace_name
ORDER BY 4 DESC;

/* Another way to generate an alert is with the following query where it is verified
the total size of the used and shows an aggregate threshold as a column */

SELECT m.tablespace_name,
    round(max(m.used_percent),1)  PERCM,
    round(max(m.used_space*t.block_size)*100/(sum(d.bytes)*count(distinct d.file_id)/count(d.file_id)),1) PERC,
    round(max(m.tablespace_size*t.block_size/1024/1024),1) TOTALM,
    round((sum(d.bytes)*count(distinct d.file_id))/count(d.file_id)/1024/1024,1) TOTAL,
    round(max(m.used_space*t.block_size/1024/1024),1) USED,
    round(max((m.tablespace_size-m.used_space)*t.block_size/1024/1024),1) FREEM,
    round(((sum(d.bytes)*count(distinct d.file_id))/count(d.file_id)-max(m.used_space*t.block_size))/1024/1024,1) FREE,     
    count(distinct d.file_id) DBF_NO,
    max(to_number(tt.warning_value)) WARN,
    max(to_number(tt.critical_value)) CRIT,
    max(case when m.used_percent>tt.warning_value OR m.used_percent>tt.critical_value then 'NO!' else 'OK' end) "OK?"
FROM  dba_tablespace_usage_metrics m, dba_tablespaces t, dba_data_files d, dba_tablespace_thresholds tt
WHERE m.tablespace_name=t.tablespace_name
AND d.tablespace_name=t.tablespace_name
AND tt.tablespace_name=d.tablespace_name
AND tt.metrics_name='Tablespace Space Usage'
GROUP BY m.tablespace_name
ORDER BY 2 desc;
