SELECT acl,
       principal,
       privilege,
       is_grant,
       TO_CHAR(start_date, 'DD-MON-YYYY') AS start_date,
       TO_CHAR(end_date, 'DD-MON-YYYY') AS end_date
FROM   dba_network_acl_privileges
where acl like '%acl_sas_vimed.xml%';

DBA_NETWORK_ACLS

SELECT HOST
      ,lower_port
      ,upper_port
      ,acl
  FROM dba_network_acls;


-- crear
BEGIN
DBMS_NETWORK_ACL_ADMIN.CREATE_ACL (
acl => '/sys/acls/acl_sas_vimed.xml',
description => 'Network Access Control APP_IAA_INTERFAZ',
principal => 'APP_IAA_INTERFAZ',
is_grant => TRUE,
privilege => 'connect');
commit;
END;
/


--permisos
BEGIN
DBMS_NETWORK_ACL_ADMIN.add_privilege (
acl => '/sys/acls/acl_sas_vimed.xml',
principal => 'APP_IAA_INTERFAZ',
is_grant => TRUE,
privilege => 'resolve',
position => NULL,
start_date => NULL,
end_date => NULL); COMMIT;
END;
/
--- asignar
BEGIN
DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL (
acl => '/sys/acls/acl_sas_vimed.xml',
host => 'http://api-test.rimac.com.pe:8043/Services/IntegracionSASWS.asmx',
lower_port => 8043 ,
upper_port => 8043 
);
COMMIT;
END;
/


3.1.3 Asignando ACL
En este caso usaré el puerto 587 aunque también pueden validar con el puerto 25 ó 467.
Puerto para SSL: 465
Puerto para TLS/STARTTLS: 587

BEGIN
DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL (
acl => 'utl_mail_monitor.xml',
host => 'smtp.gmail.com',
lower_port => 587,
upper_port => 587
);
COMMIT;
END;
/

3.1.4 Validación de ACL
Además de las vistas de ACL, los privilegios se pueden verificar utilizando las funciones CHECK PRIVILEGE y CHECK_PRIVILEGE_ACLID del paquete DBMS_NETWORK_ACL_ADMIN.

SELECT DECODE(DBMS_NETWORK_ACL_ADMIN.CHECK_PRIVILEGE(
'/sys/acls/utl_mail_monitor.xml', 'DBA_MONITOR', 'resolve'),
1, 'GRANTED', 0, 'DENIED', NULL) PRIVILEGE
FROM DUAL;

SELECT * FROM dba_network_acls;

SELECT acl,
principal,
privilege,
is_grant,
TO_CHAR(start_date, 'DD-MON-YYYY') AS start_date,
TO_CHAR(end_date, 'DD-MON-YYYY') AS end_date
FROM dba_network_acl_privileges;

3.1.5 Eliminando ACL
Para eliminar un ACL se usa el siguiente comando:

BEGIN
dbms_network_acl_admin.drop_acl('utl_mail_monitor.xml');
END;
/

3.1.6 Desasignando ACL
BEGIN
DBMS_NETWORK_ACL_ADMIN.UNASSIGN_ACL(
acl => 'utl_mail_monitor.xml',
host => 'smtp.gmail.com',
lower_port => 587,
upper_port => 587
);
COMMIT;
END;
/

3.1.7 Eliminar Privilegio
BEGIN
DBMS_NETWORK_ACL_ADMIN.DELETE_PRIVILEGE(
'utl_mail_monitor.xml', 'DBA_MONITOR', NULL, 'connect'
);
COMMIT;
END;
/

==================================================================

-- Ejecutar como sysdba
DECLARE
  l_acl       VARCHAR2(100) := 'nombredemiacl.xml';
  l_desc      VARCHAR2(100) := 'descripción del acl';
  l_principal VARCHAR2(30)  := 'USUARIO'; -- EN MAYÚSCULAS
  l_host      VARCHAR2(100) := 'ldap.ejemplo.com'; --nombre del host
BEGIN
  -- Crea el nuevo ACL
  -- Proveer privilegios de conexión 
  dbms_network_acl_admin.create_acl(l_acl, l_desc, l_principal, TRUE, 'connect');
 
  -- Permisos de resolución de DNS
  dbms_network_acl_admin.add_privilege(l_acl, l_principal, TRUE, 'resolve');
 
  -- Pasamos lo parámetros nombre del acl y host
  dbms_network_acl_admin.assign_acl(l_acl, l_host);
 
  COMMIT;
END;
