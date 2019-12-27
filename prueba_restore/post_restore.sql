!date
set time on
select open_mode from v$database;
alter database open resetlogs;
select open_mode from v$database;
!echo $ORACLE_HOME
