/*
@Author: E. Yair Purisaca R.
@Email: eddiepurisaca@gmail.com
Tamaño de tablespace usando ** dba_tablespace_usage_metrics ** esta vista nos permite ver
el espacio total utilizado, basado a su vez en el espacio disponible en el filesystem.
Ejemplo:
Tablespace System tiene un datafile system01.dbf de tamaño de 10 GB como MAXSIZE del cual
el tamaño actual es de 5 GB donde el espacio utilizado es de 4.5Gb
por lo que la vista dba_tablespace_usage_metrics considera que el Tbalespace es del 50%
de su uso.
Si se utiliza la consulta en dba_extents, esto es solo sobre el tamaño de los datafiles
en uso, por lo que en el ejemplo es 5GB el tamaño actual y en uso de 4.5Gb, lo que causaría
la alerta se activa ya que se "usa" más del 80%.
dba_tablespace_usage_metrics nos da una métrica más precisa*/

--Comparación de dba_tablespace_usage_metrics con valores de dba_tablespaces,dba_data_files, dba_free_space:
SELECT m.tablespace_name,
    round(max(m.used_percent),1) PERCM,
    round(((sum(d.bytes)*count(distinct d.file_id))/count(d.file_id)-NVL(sum(f.bytes),0)/count(distinct d.file_id))*100/(sum(d.bytes)*count(distinct d.file_id)/count(d.file_id)),1) PERC,
    round(max(m.tablespace_size*t.block_size/1024/1024),1) TOTALM,
    round(max(m.used_space*t.block_size/1024/1024),1) USED,
    round(max((m.tablespace_size-m.used_space)*t.block_size/1024/1024),1) FREEM
FROM  dba_tablespace_usage_metrics m, dba_tablespaces t, dba_data_files d, dba_free_space f
WHERE m.tablespace_name=t.tablespace_name
AND d.tablespace_name=t.tablespace_name
AND d.tablespace_name=f.tablespace_name
GROUP BY m.tablespace_name;
                               
SELECT
  a.tablespace_name AS "Nombre Tablespace",
  ROUND((a.used_space * b.block_size) / 1048576, 2) AS "Espacio Usadp (MB)",
  ROUND((a.tablespace_size * b.block_size) / 1048576, 2) AS "Tamaño Tablespace (MB)",
  ROUND(a.used_percent, 2) AS "Used %"
FROM dba_tablespace_usage_metrics a
  JOIN dba_tablespaces b 
  ON a.tablespace_name = b.tablespace_name
ORDER BY 4 DESC;

--Uso de dba_tablespace_usage_metrics
/* Si sale "invalid number" como mensaje de error, comentar los 3 consultas con la funcion max y revisar la vista dba_tablespace_thresholds
quiza haya valores que no esta evaluando.*/

SELECT m.tablespace_name,
    round(max(m.used_percent),1) PERCM,
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
order by 2 desc;
