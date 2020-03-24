--https://programmersnotes.com/2018/05/how-to-shrink-oracle-database-undo-tablespace-data-file/
--https://dbaclass.com/article/drop-and-recreate-undo-tablespace/
--https://programmersnotes.com/2018/05/how-to-drop-corrupted-undo-tablespace-segment-of-oracle-database/

Sometimes we may require to drop the existing tablespace undo and create a fresh one if the size of undo has increased a lot and we are unable to reclaim it.
Below are the steps:

1. Check the existing UNDO details:
 
SQL> show parameter undo
 
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
temp_undo_enabled                    boolean     FALSE
undo_management                      string      AUTO
undo_retention                       integer     900
undo_tablespace                      string      UNDOTBS1
 
2. Create a new undo tablespace:
 
SQL> create undo tablespace UNDOTBS_NEW datafile 
'/archive/NONPLUG/NONCDB/PLUG/undo_new01.dbf' size 1g;
 
Tablespace created.
 
3. Update undo_tablespace parameter
 
SQL> alter system set undo_tablespace=UNDOTBS_NEW scope=both;
 
System altered.
 
SQL>  show parameter undo
 
NAME                                 TYPE        VALUE
------------------------------------ ----------- --------------
temp_undo_enabled                    boolean     FALSE
undo_management                      string      AUTO
undo_retention                       integer     900
undo_tablespace                      string      UNDOTBS_NEW
 
4. Check for the active rollback segment in old tablespace
 
set pagesize 200
set lines 200
set long 999
col username for a9
SELECT a.name,b.status , d.username , d.sid , d.serial#
FROM   v$rollname a,v$rollstat b, v$transaction c , v$session d
WHERE  a.usn = b.usn
AND    a.usn = c.xidusn
AND    c.ses_addr = d.saddr
AND    a.name IN ( 
  SELECT segment_name
  FROM dba_segments 
 WHERE tablespace_name = 'UNDOTBS1'
);
 
 
NAME                           STATUS          USERNAME         SID    SERIAL#
------------------------------ --------------- --------- ---------- ----------
_SYSSMU10_2630303337$          PENDING OFFLINE DBACLASS         271      42722
 
5. Kill the session using old tablespace
System altered.
 
SQL> alter system kill session '271,42722' immediate;

4.1 Check if all related old undo tablespace segments went OFFLINE:

select tablespace_name, segment_name, status 
from dba_rollback_segs where tablespace_name='UNDOTBS1'

If some of them still have status ONLINE, take them offline by executing (example):
alter rollback segment "_SYSSMU3_3285411314$" offline;

If some of them have status NEEDS RECOVERY, you’ll need a bit more effort to drop them.
How to proceed with it, please check post – How to drop corrupted “undo” tablespace segment of Oracle database?
--https://programmersnotes.com/2018/05/how-to-drop-corrupted-undo-tablespace-segment-of-oracle-database/

6. Drop the old undo tablespace
 
SQL> DROP TABLESPACE undotbs1 INCLUDING CONTENTS AND DATAFILES;
 
Tablespace dropped.
