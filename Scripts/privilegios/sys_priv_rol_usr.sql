/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2018
*@Descripcion:             System privileges to roles and users
                           This is also possible the other way round: showing the system privileges in relation to 
                           roles that have been granted this privilege and users that have been granted either this 
                           privilege or a role
*@Argumentos               PRIVILEGIO: Evalua y muestra en un arbol el privilegio consultado a que usuarios o roles ha 
                           sido asignado
*******************************************************************************************************************/

select
  lpad(' ', 2*level) || c "Privilege, Roles and Users"
from
  (
  /* THE PRIVILEGES */
    select 
      null   p, 
      name   c
    from 
      system_privilege_map
    where
      name like upper('%&enter_privliege%')
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      granted_role  p,
      grantee       c
    from
      dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      privilege     p,
      grantee       c
    from
      dba_sys_privs
  )
start with p is null
connect by p = prior c;
