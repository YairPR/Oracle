--Below script is useful in getting CPU, memory and core, socket information of a database server from SQL prompt.
 
set pagesize 299
set lines 299
select STAT_NAME,to_char(VALUE) as VALUE  ,COMMENTS from v$osstat where stat_name  IN ('NUM_CPUS','NUM_CPU_CORES','NUM_CPU_SOCKETS')
union
select STAT_NAME,VALUE/1024/1024/1024 || ' GB'  ,COMMENTS from v$osstat where stat_name  IN ('PHYSICAL_MEMORY_BYTES')
 

