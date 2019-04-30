/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2018
*@Descripcion:             Users to roles and system privileges
                           This is a script that shows the hierarchical relationship between system privileges, roles and users.
                           It makes use of Oracles connect by SQL idiom.
*@Argumentos               usuario          Usuario al cual se dara permiso with grant  option 
*******************************************************************************************************************/

select
  lpad(' ', 2*level) || granted_role "User, his roles and privileges"
from
  (
  /* THE USERS */
    select 
      null     grantee, 
      username granted_role
    from 
      dba_users
    where
      username like upper('%&enter_username%')
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      grantee,
      granted_role
    from
      dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      grantee,
      privilege
    from
      dba_sys_privs
  )
start with grantee is null
connect by grantee = prior granted_role;
