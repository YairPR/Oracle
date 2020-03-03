set lines 500;
set pages 500;
set serveroutput on

col user_name format a20
col status format a20
col DEFAULT_tablespace format a25
col temp_tablespace format a25
col date_creation format a20
col last_change_password format a20
col last_expired_password format a20
col last_lock format a20


accept vuser prompt "usuario: ";

SET VERIFY OFF

select u.name user_name, u.password, (case u.astatus when 0 then 'Open' when 1 then 'Expired' when 2 then 'Expired(GRACE)' when 4 then 'Locked(TIMED)' when 5 then 'Expired and Locked(TIMED)' when 6 then 'Expired(GRACE) and Locked(TIMED)' when 8 then 'Locked' when 9 then 'Expired and Locked' when 10 then 'Expired(GRACE) and Locked'  when 16 then 'Password matches a default value' else 'Nothing' end) status, 
t.name DEFAULT_tablespace, e.name temp_tablespace, ctime date_creation, ptime last_change_password, exptime last_expired_password, ltime last_lock
from sys.user$ u, v$tablespace t, v$tablespace e
where u.type# = 1
and  u.name = upper('&vuser')
and u.datats# = t.ts#
and u.tempts# = e.ts#;

SET HEADING OFF


select 'SCRIPT:' from dual;

select '--Usuario' from dual;

col script_user format a50

select 'create user ' || to_char(u.name) || chr(10) ||
'identified by values ' || u.password || chr(10) ||
'default tablespace ' || t.name  || chr(10) ||
'temporary tablespace ' || e.name || chr(10) ||
'profile <name_profile>;' script_user
from sys.user$ u, v$tablespace t, v$tablespace e
where u.type# = 1
and  u.name = upper('&vuser')
and u.datats# = t.ts#
and u.tempts# = e.ts#;

select '--Roles' from dual;

col roles format a50

select 'grant ' || r.granted_role || ' to ' || r.grantee || ';'  roles from dba_ROLE_PRIVS r where Grantee=upper('&vuser');

select '--System Privileges' || chr(10) from dual;

col system_pri format a50

select 'grant ' ||s.privilege || ' to ' || s.grantee || ';'  system_pri from dba_SYS_PRIVS s where Grantee=upper('&vuser');

select '--Object Privileges' || chr(10) from dual;

col object_pri format a100

select 'grant ' ||o.privilege || ' on ' || o.owner || '.' || o.table_name  || ' to ' || o.grantee || ';'  object_pri from dba_TAB_PRIVS o where Grantee=upper('&vuser') and o.owner not in  ( 'SYS','SYSTEM');

SET HEADING ON
SET VERIFY ON
