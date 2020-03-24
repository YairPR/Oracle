--https://programmersnotes.com/2018/05/how-to-shrink-oracle-database-undo-tablespace-data-file/

1.Check which file is used for undo tablespace
select tablespace_name,file_name from dba_data_files;

2.Create new undo tablespace. Recommended at the same filesystem path to keep consistency.

create undo tablespace UNDOTBS2 datafile '/opt/oracle/database/oradata/promis/undotbs02.dbf' size 100M;

3.Tell the system to use new undo tablespace from current point of time. This is done by changing system parameter:
alter system set undo_tablespace=UNDOTBS2;

4.Restart database instance. Using database server command line connect to DB instance as sysdba. Shutdown immediate and startup database instance:
$sqlplus / as sysdba
SQL>shutdown immediate
...
SQL>startup

5.If you experience issues by connecting to database instance directly from server command line, please check this post – Why can’t connect to Oracle instance using “sqlplus / as sysdba” ?
Check if all related old undo tablespace segments went OFFLINE:

select tablespace_name, segment_name, status from dba_rollback_segs where tablespace_name='UNDOTBS1'

6.If some of them still have status ONLINE, take them offline by executing (example):
alter rollback segment "_SYSSMU3_3285411314$" offline;

7.If some of them have status NEEDS RECOVERY, you’ll need a bit more effort to drop them. How to proceed with it, please check post – How to drop corrupted “undo” tablespace segment of Oracle database?
When there is no other status then OFFLINE available between segments belonged to old undo tablespace, you can drop it:

drop tablespace UNDOTBS1 including contents and datafiles;

Thats it. Enjoy extra free disk space!

