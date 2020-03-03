alter database open resetlogs;
select status from V$Instance;
select open_mode from V$database;
exit;
