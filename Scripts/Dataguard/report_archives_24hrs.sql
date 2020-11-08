
set line 1000
set trimspool on
column secuencia 999999
column nombre format a97
column first_time format a13
column completado format a12
select sequence# secuencia, 
       substr(name,1,96) nombre,creator, 
       registrar,
       to_char(first_time,'DD-MON HH24:MI') first_time, 
       to_char(completion_time,'DD-MON HH24:MI') completado,
       status,
       applied
  from v$archived_log
  where first_time > sysdate-1
  order by 1
/
