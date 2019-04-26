-- Creacion de Roles
-- E. Yair Purisaca Rivera
-- 31/10/2018
-- Create Roles
create role ROL_DDL_UTEC; --  Rol Administrador
   create role ROL_CREATE; -- crear solo si no necesita dar privilegio para otro esquema ya que en ese caso no servirá 
                             --porque se tendria que usar ANY rivilegio direco al usuario
   create role ROL_ALTER_TAB;
   create role ROL_ALTER_NOTAB;
   create role ROL_COMPILE; -- para los 3 roles; solo en caso corresponda
create role ROL_DML_UTEC; --  Rol Administrador
   create role ROL_INSERT;
   create role ROL_UPDATE;
   create role ROL_DELETE;
create role ROL_QUERY_UTEC; --  Rol Administrador
   create role ROL_SELECT;
   create role ROL_DEBUG;
   create role ROL_EXECUTE;
 
-- GRANTS DE ROL A ROL ADMIN

select ' grant ' || ROLE || ' to ;' from dba_roles where role NOT like '%_UTEC' and role like 'ROL_%' 

 grant ROL_ALTER_TAB to ROL_DDL_UTEC ;
 grant ROL_ALTER_NOTAB to  ROL_DDL_UTEC;
 grant ROL_COMPILE to ROL_DDL_UTEC ;
 grant ROL_COMPILE to ROL_DML_UTEC ;
 grant ROL_COMPILE to  ROL_QUERY_UTEC;
 grant ROL_INSERT to ROL_DML_UTEC ;
 grant ROL_UPDATE to  ROL_DML_UTEC;
 grant ROL_DELETE to ROL_DML_UTEC ;
 grant ROL_SELECT to ROL_QUERY_UTEC ;
 grant ROL_DEBUG to  ROL_QUERY_UTEC;
 grant ROL_EXECUTE to ROL_QUERY_UTEC ;
 grant ROL_CREATE to ROL_DDL_UTEC ;
 
 -- GRANT ROLE ADMIN A USUARIO
 
 GRANT ROL_DDL_UTEC TO JENKINS;
 GRANT ROL_DML_UTEC TO JENKINS;
 GRANT ROL_QUERY_UTEC TO JENKINS;
