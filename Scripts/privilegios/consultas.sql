-- AYUDAS
--Crear sinonimo
create or replace synonym UTEC.ACA_ALUMNO_CONVALIDA_DOCU for ACADEMICO.ACA_ALUMNO_CONVALIDA_DOCU;

-- Grant debug para ver package
GRANT DEBUG ON <name of package> to <name of user>; 

-- Crear Roles
CREATE ROLE ROL_EXECUTE;

-- Grant any table a rol
grant select any table to ROL_SELECT with admin option;

-- Grant execute function o package
GRANT EXECUTE ON UTEC.FN_GET_ELAPSED_TIME_MILLIS TO DESARROLLO;

-- revocar role
REVOKE rol_ddl_prymera FROM jjuarez;
REVOKE DBA FROM AURDAY;

-- Privilegios otorgados sobre objetos: dba_tab_privs, all_tab_privs and user_tab_privs
SELECT * FROM DBA_TAB_PRIVS WHERE GRANTEE = 'ROL_SELECT'

SELECT * FROM ROLE_TAB_PRIVS WHERE ROLE = 'ROL_SELECT';

SELECT * FROM DBA_ROLE_PRIVS WHERE GRANTEE = 'SOPORTE'

-- Muestra privilegios para un usuario
select granted_role, admin_option, default_role
from dba_role_privs
where grantee = 'RNYFFENEGGER'
order by granted_role;

