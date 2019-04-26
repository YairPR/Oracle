/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2018
*@Descripcion:             Genera y ejcuta los permisos sobre un usuario o rol especificado
*@Argumentos               usuario          Usuario al cual se dara permiso with grant  option 
*******************************************************************************************************************/
CREATE OR REPLACE PROCEDURE GRANTS_ROLUSER (usuario varchar)
IS 

  o_type VARCHAR2(60) := '';
  o_name VARCHAR2(60) := '';
  o_owner VARCHAR2(60) := '';
  l_error_message VARCHAR2(500) := '';
  
      TYPE string_collection IS TABLE OF VARCHAR2 (30);

    sql_function_codes CONSTANT string_collection
       := string_collection (
             'CREATE TABLE',
             'SET ROLE',
             'INSERT',
             'SELECT',
             'UPDATE',
             'DROP ROLE',
             'DROP VIEW',
             'DROP TABLE',
             'DELETE',
             'CREATE VIEW',
             'DROP USER',
             'CREATE ROLE',
             'CREATE SEQUENCE',
             'ALTER SEQUENCE',
             '(NOT USED)',
             'DROP SEQUENCE',
             'CREATE SCHEMA',
             'CREATE CLUSTER',
             'CREATE USER',
             'CREATE INDEX',
             'DROP INDEX',
             'DROP CLUSTER',
             'VALIDATE INDEX',
             'CREATE PROCEDURE',
             'ALTER PROCEDURE',
             'ALTER TABLE',
             'EXPLAIN',
             'GRANT',
             'REVOKE',
             'CREATE SYNONYM',
             'DROP SYNONYM',
             'ALTER SYSTEM SWITCH LOG',
             'SET TRANSACTION',
             'PL/SQL EXECUTE',
             'LOCK',
             'NOOP',
             'RENAME',
             'COMMENT',
             'AUDIT',
             'NO AUDIT',
             'ALTER INDEX',
             'CREATE EXTERNAL DATABASE',
             'DROP EXTERNAL DATABASE',
             'CREATE DATABASE',
             'ALTER DATABASE',
             'CREATE ROLLBACK SEGMENT',
             'ALTER ROLLBACK SEGMENT',
             'DROP ROLLBACK SEGMENT',
             'CREATE TABLESPACE',
             'ALTER TABLESPACE',
             'DROP TABLESPACE',
             'ALTER SESSION',
             'ALTER USER',
             'COMMIT (WORK)',
             'ROLLBACK',
             'SAVEPOINT',
             'CREATE CONTROL FILE',
             'ALTER TRACING',
             'CREATE TRIGGER',
             'ALTER TRIGGER',
             'DROP TRIGGER',
             'ANALYZE TABLE',
             'ANALYZE INDEX',
             'ANALYZE CLUSTER',
             'CREATE PROFILE',
             'DROP PROFILE',
             'ALTER PROFILE',
             'DROP PROCEDURE',
             '(NOT USED)',
             'ALTER RESOURCE COST',
             'CREATE SNAPSHOT LOG',
             'ALTER SNAPSHOT LOG',
             'DROP SNAPSHOT LOG',
             'CREATE SNAPSHOT',
             'ALTER SNAPSHOT',
             'DROP SNAPSHOT',
             'CREATE TYPE',
             'DROP TYPE',
             'ALTER ROLE',
             'ALTER TYPE',
             'CREATE TYPE BODY',
             'ALTER TYPE BODY',
             'DROP TYPE BODY',
             'DROP LIBRARY',
             'TRUNCATE TABLE',
             'TRUNCATE CLUSTER',
             'CREATE BITMAPFILE',
             'ALTER VIEW',
             'DROP BITMAPFILE',
             'SET CONSTRAINTS',
             'CREATE FUNCTION',
             'ALTER FUNCTION',
             'DROP FUNCTION',
             'CREATE PACKAGE',
             'ALTER PACKAGE',
             'DROP PACKAGE',
             'CREATE PACKAGE BODY',
             'ALTER PACKAGE BODY',
             'DROP PACKAGE BODY') ;

BEGIN

FOR C IN (SELECT OWNER, OBJECT_NAME,OBJECT_TYPE
          FROM DBA_OBJECTS
          WHERE OWNER IN ('TRAMITE', 'EGRESADO', 'FINANZAS', 'CALENDAR','MATRICULA','TIMETABLE','AUDITORIA',
                          'UTEC','SEGURIDAD','GENERAL','COMERCIAL','ACADEMICO','PROGRAMACION','CONFIGURACION',
                          'PREMATRICULA','RESERVA','WORKFLOW')
          AND OBJECT_TYPE IN ('TABLE','SEQUENCE','VIEW','PROCEDURE','FUNCTION','PACKAGE','TYPE'))
    LOOP
    BEGIN
    o_type := c.object_type;
    o_owner := c.owner;
    o_name := c.object_name;

    IF o_type='TABLE' THEN
       --DBMS_OUTPUT.PUT_LINE(o_type||' '||o_owner||'.'||o_name);
       --DBMS_OUTPUT.PUT_LINE ('grant Select on ' || o_owner || '.' || o_name || ' to ROL_SELECT');
       EXECUTE IMMEDIATE 'grant Select on "' || o_owner || '"."' || o_name || '" to ROL_SELECT';
       EXECUTE IMMEDIATE('grant Select on ' || o_owner || '.' || o_name || ' to ' || usuario || ' WITH GRANT OPTION');
       EXECUTE IMMEDIATE('grant Insert on ' || o_owner || '.' || o_name || ' to ROL_INSERT');
       EXECUTE IMMEDIATE('grant Update on ' || o_owner || '.' || o_name || ' to ROL_UPDATE');
       EXECUTE IMMEDIATE('grant Delete on ' || o_owner || '.' || o_name || ' to ROL_DELETE');
       EXECUTE IMMEDIATE('grant Alter on ' || o_owner || '.' || o_name || ' to ROL_ALTER_TAB'); ---modify table (columns,PK,FK,CHK,comments)
       dbms_output.put_line (sql_function_codes (dbms_sql.last_sql_function_code) || ' succeeded.');
    ELSIF (o_type='PROCEDURE' OR o_type='FUNCTION' OR o_type='PACKAGE' OR o_type='TYPE') THEN
       EXECUTE IMMEDIATE('grant EXECUTE on ' || o_owner || '.' || o_name || ' to ROL_EXECUTE');
       EXECUTE IMMEDIATE('grant DEBUG on ' || o_owner || '.' || o_name || ' to ROL_DEBUG');
       dbms_output.put_line (sql_function_codes (dbms_sql.last_sql_function_code) || ' succeeded.');
    ELSIF o_type='VIEW' THEN
       EXECUTE IMMEDIATE('grant SELECT on ' || o_owner || '.' || o_name || ' to ROL_SELECT');
       dbms_output.put_line (sql_function_codes (dbms_sql.last_sql_function_code) || ' succeeded.');
    ELSIF o_type='SEQUENCE' THEN
       EXECUTE IMMEDIATE('grant SELECT on ' || o_owner || '.' || o_name || ' to ROL_SELECT');
       dbms_output.put_line (sql_function_codes (dbms_sql.last_sql_function_code) || ' succeeded.');
    END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_error_message := sqlerrm;
        DBMS_OUTPUT.PUT_LINE('Error with '||o_type||' '||o_owner||'.'||o_name||': '|| l_error_message);
        CONTINUE;
    END;
END LOOP;
END;
/
