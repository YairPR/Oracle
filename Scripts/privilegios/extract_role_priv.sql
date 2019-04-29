 --Script to Extract Role granted Privileges in Oracle
  select role, 'ROL' type, granted_role pv
  from role_role_privs
 where role like '%&rolecheck%'
union
select role, 'PRV' type, privilege pv
  from role_sys_privs
 where role like '%&rolecheck%'
union
select role,
       'OBJ' type,
       max(decode(privilege, 'WRITE', 'WRITE,')) ||
       max(decode(privilege, 'READ', 'READ')) ||
       max(decode(privilege, 'EXECUTE', 'EXECUTE')) ||
       max(decode(privilege, 'SELECT', 'SELECT')) ||
       max(decode(privilege, 'DELETE', ',DELETE')) ||
       max(decode(privilege, 'UPDATE', ',UPDATE')) ||
       max(decode(privilege, 'INSERT', ',INSERT')) || ' ON ' || object_type || ' "' ||
       a.owner || '.' || table_name || '"' pv
  from role_tab_privs a, dba_objects b
 where role like '%&rolecheck%'
   and a.owner = b.owner
   and a.table_name = b.object_name
 group by a.owner, table_name, object_type, role
union
select role, '---' type, 'this is an empty role ---' pv
  from dba_roles
 where not role in (select distinct role from role_role_privs)
   and not role in (select distinct role from role_sys_privs)
   and not role in (select distinct role from role_tab_privs)
   and role like '%&rolecheck%'
 group by role
 order by role, type, pv;
