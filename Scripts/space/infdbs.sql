-- info tablesce datafile creation tamaño (no temp)
select
substr(a.tablespace_name,1,10) as Tablespace_Name,
substr(a.file_name,1,40) as File_Name,
a.bytes/1024/1024 as Size_Mb,
b.creation_time
from dba_data_files a, v$datafile b where a.file_name=b.name
and upper(a.tablespace_name) = '&nombre_tbs'
order by tablespace_name, file_name;
