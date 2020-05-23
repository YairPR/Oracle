--How to fix ORA-00054
/*
Solution
There are three workarounds to address this.

Using DDL_LOCK_TIMEOUT
You can increased the timeout by modifying the DDL_LOCK_TIMEOUT parameter in your session. Once this is set Oracle will wait for the new TIMEOUT before returning the “ORA-00054: resource busy and acquire with NOWAIT specified” error.

SQL> ALTER SESSION SET ddl_lock_timeout=900;
Session altered.
SQL> ALTER TABLE vst.account ADD (update_date varchar2(100));
Table altered.
*/

SELECT a.object, a.type, a.sid,
s.serial#, s.username,
s.program, s.logon_time
FROM v$access a, v$session s
WHERE a.sid = s.sid
AND a.owner = '&owner'
AND a.object = '&object_name';
