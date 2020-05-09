Bajar:
Next, Stop and Restart standby managed recovery process
alter database recover managed standby database cancel;

Activar
alter database recover managed standby database disconnect from session;

Verificar
select process,status,thread#,sequence# from v$managed_standby;
