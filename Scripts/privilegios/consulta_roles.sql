--ROLES CON PASSWD
select p.grantee,p.granted_role,p.admin_option
from dba_role_privs p,
dba_roles r
where exists (select 'x'
 from dba_roles d
 where d.password_required='YES'
 and d.role=p.granted_role)
 and p.grantee=r.role
 
  -- roles y grant por usuario
SELECT DBA_TAB_PRIVS.GRANTEE, TABLE_NAME, PRIVILEGE,DBA_ROLE_PRIVS.GRANTEE
FROM DBA_TAB_PRIVS, DBA_ROLE_PRIVS
WHERE DBA_TAB_PRIVS.GRANTEE = DBA_ROLE_PRIVS.GRANTED_ROLE
AND DBA_TAB_PRIVS.GRANTEE='JENKINS'
AND DBA_ROLE_PRIVS.GRANTEE = 'ROL_SELECT'
ORDER BY DBA_ROLE_PRIVS.GRANTEE

-- Roles asignados a usuario
select GRANTEE, GRANTED_ROLE from DBA_ROLE_PRIVS
where grantee in ('JENKINS')
ORDER BY 1

 
 -- GRANT DE OBJETOS A ROLES
select 'grant '||privilege||' on '||owner||'.'||table_name||' to '||grantee
         ||case when grantable = 'YES' then ' with grant option' else null end
         ||';'
from dba_tab_privs
where owner in ('ACADEMICO', 'UTEC')
and grantee in ( select role from dba_roles )
order by grantee, owner

-- GRANTS ROLES A ROLES
select 'grant '||granted_role||' to '||grantee
         ||case when admin_option = 'YES' then ' with admin option' else null end
         ||';'
from dba_role_privs
where grantee in ( select role from dba_roles )
order by grantee, granted_role

--Note that these scripts don't generate grants for system privileges. Also, life is slightly more complicated if 
--you use directory objects because that requires an additional key word...

select 'grant '||privilege||' on '||owner||'.'||table_name||' to '||grantee
         ||case when grantable = 'YES' then ' with grant option' else null end
         ||';'
from dba_tab_privs
where owner in ('ACADEMICO', 'UTEC')
and grantee in ( select role from dba_roles )
and table_name not in ( select directory_name from dba_directories )
union all
select 'grant '||privilege||' on directory '||table_name||' to '||grantee
         ||case when grantable = 'YES' then ' with grant option' else null end
         ||';'
from dba_tab_privs
where grantee in ( select role from dba_roles )
and table_name  in ( select directory_name from dba_directories )

