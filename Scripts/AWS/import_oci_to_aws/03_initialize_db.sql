/*03092021  epurisaca  Se adiciona el script para eliminar sesiones del usuario UTEC y evitar ORA-01940*/
WHENEVER SQLERROR EXIT 2
SET SERVEROUTPUT ON

dbms_output.put_line('LOCK USER UTEC');
dbms_output.put_line('----------------');
alter user utec account lock;

dbms_output.put_line('KILL SESSION UTEC');
dbms_output.put_line('----------------');
BEGIN
  for session_to_drop in (select SID, SERIAL#  from v$session WHERE username = 'UTEC')
  loop
    rdsadmin.rdsadmin_util.kill(session_to_drop.sid, session_to_drop.serial#, method => 'IMMEDIATE');
  end loop;
end;
/

declare
  type table_varchar  is table of varchar2(50);
  var_table_varchar  table_varchar;
  V_USER varchar2(50);
begin

dbms_output.put_line('DROP USERS');
dbms_output.put_line('----------------');

  var_table_varchar  := table_varchar('UNITIME','DESARROLLO','UTEC','ACADEMICO', 'COMERCIAL', 'CONFIGURACION', 'GENERAL', 'PROGRAMACION', 'SEGURIDAD', 'AUDITORIA', 'MATRICULA', 'PREMATRICULA', 'TIMETABLE', 'CALENDAR', 'FINANZAS', 'EGRESADO', 'TRAMITE', 'RESERVA', 'WORKFLOW');
  for elem in 1 .. var_table_varchar.count loop
    dbms_output.put_line(elem || ': ' || var_table_varchar(elem));

    BEGIN
      select UNIQUE username INTO V_USER from dba_users WHERE username = var_table_varchar(elem);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      V_USER := NULL;
    END;

    IF V_USER IS NOT NULL THEN
      execute immediate 'DROP USER ' || var_table_varchar(elem) || ' CASCADE';
    END IF;

  end loop;
end;
/

declare
  type table_varchar  is table of varchar2(50);
  var_table_varchar  table_varchar;
  V_TABLESPACE varchar2(50);
begin

  dbms_output.put_line('DROP TABLESPACES');
  dbms_output.put_line('----------------');

  var_table_varchar  := table_varchar('UNITIME','DESARROLLO','UTEC','ACADEMICO', 'COMERCIAL', 'CONFIGURACION', 'GENERAL', 'PROGRAMACION', 'SEGURIDAD', 'AUDITORIA', 'MATRICULA', 'PREMATRICULA', 'TIMETABLE', 'CALENDAR', 'FINANZAS', 'EGRESADO', 'TRAMITE', 'RESERVA', 'WORKFLOW');
  for elem in 1 .. var_table_varchar.count loop
    dbms_output.put_line(elem || ': ' || var_table_varchar(elem));

    BEGIN
      SELECT UNIQUE TABLESPACE_NAME INTO V_TABLESPACE FROM DBA_TABLESPACES WHERE TABLESPACE_NAME = 'TS_' || var_table_varchar(elem);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      dbms_output.put_line('not found');
      V_TABLESPACE := NULL;
    END;

    IF V_TABLESPACE IS NOT NULL THEN
      dbms_output.put_line('tablespace ' || var_table_varchar(elem) || ' was found, drop it!');
      execute immediate 'DROP TABLESPACE TS_' || var_table_varchar(elem) || ' INCLUDING CONTENTS  CASCADE CONSTRAINTS';
    END IF;

    BEGIN
      SELECT UNIQUE TABLESPACE_NAME INTO V_TABLESPACE FROM DBA_TABLESPACES WHERE TABLESPACE_NAME = 'TS_' || var_table_varchar(elem)|| '_IDX';
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      V_TABLESPACE := NULL;
    END;

    IF V_TABLESPACE IS NOT NULL THEN
      execute immediate 'DROP TABLESPACE TS_' || var_table_varchar(elem) || '_IDX INCLUDING CONTENTS  CASCADE CONSTRAINTS';
    END IF;

  end loop;
end;
/

declare
  type table_varchar  is table of varchar2(50);

  var_table_varchar  table_varchar;
begin

dbms_output.put_line('CREATE TABLESPACES');
dbms_output.put_line('----------------');

  var_table_varchar  := table_varchar('UNITIME','DESARROLLO','UTEC','ACADEMICO', 'COMERCIAL', 'CONFIGURACION', 'GENERAL', 'PROGRAMACION', 'SEGURIDAD', 'AUDITORIA', 'MATRICULA', 'PREMATRICULA', 'TIMETABLE', 'CALENDAR', 'FINANZAS', 'EGRESADO', 'TRAMITE', 'RESERVA', 'WORKFLOW');
  for elem in 1 .. var_table_varchar.count loop
    dbms_output.put_line(elem || ': ' || var_table_varchar(elem));

    IF var_table_varchar(elem) = 'AUDITORIA' THEN
       dbms_output.put_line('SPECIAL TREATMENT FOR AUDITORIA');
       execute immediate 'CREATE TABLESPACE TS_' || var_table_varchar(elem) || ' DATAFILE SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 10G';
    ELSE
       execute immediate 'CREATE TABLESPACE TS_' || var_table_varchar(elem) || ' DATAFILE SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 10G';
    END IF;
    execute immediate 'CREATE TABLESPACE TS_' || var_table_varchar(elem) || '_IDX DATAFILE SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE 10G';
  end loop;
end;
/

declare
  type table_varchar  is table of varchar2(50);

  var_table_varchar  table_varchar;
begin

  dbms_output.put_line('CREATE USERS');
  dbms_output.put_line('----------------');

  var_table_varchar  := table_varchar('UNITIME','DESARROLLO','UTEC','ACADEMICO', 'COMERCIAL', 'CONFIGURACION', 'GENERAL', 'PROGRAMACION', 'SEGURIDAD', 'AUDITORIA', 'MATRICULA', 'PREMATRICULA', 'TIMETABLE', 'CALENDAR', 'FINANZAS', 'EGRESADO', 'TRAMITE', 'RESERVA', 'WORKFLOW');
  for elem in 1 .. var_table_varchar.count loop
    dbms_output.put_line(elem || ': ' || var_table_varchar(elem));
    execute immediate 'CREATE USER ' || var_table_varchar(elem) || ' IDENTIFIED BY f64808f192c8 DEFAULT TABLESPACE TS_'|| var_table_varchar(elem);
execute immediate 'GRANT UNLIMITED TABLESPACE TO ' || var_table_varchar(elem);
  end loop;
end;
/

-- GRANT CREATE SESSION TO "ACADEMICO";
-- GRANT CREATE SESSION TO "COMERCIAL";
-- GRANT CREATE SESSION TO "CONFIGURACION";
-- GRANT CREATE SESSION TO "GENERAL";
-- GRANT CREATE SESSION TO "PROGRAMACION";
-- GRANT CREATE SESSION TO "SEGURIDAD";
-- GRANT CREATE SESSION TO "AUDITORIA";
GRANT CREATE SESSION TO "UTEC";
GRANT CREATE SESSION TO "TIMETABLE";
GRANT CREATE SESSION TO "DESARROLLO";
-- GRANT CREATE SESSION TO "MATRICULA";
-- GRANT CREATE SESSION TO "PREMATRICULA";
-- GRANT CREATE SESSION TO "CALENDAR";
-- GRANT CREATE SESSION TO "FINANZAS";
-- GRANT CREATE SESSION TO "EGRESADO";
-- GRANT CREATE SESSION TO "TRAMITE";
-- GRANT CREATE SESSION TO "RESERVA";
-- GRANT CREATE SESSION TO "WORKFLOW";

alter user ACADEMICO            quota unlimited on users;
alter user COMERCIAL            quota unlimited on users;
alter user CONFIGURACION        quota unlimited on users;
alter user GENERAL                      quota unlimited on users;
alter user PROGRAMACION         quota unlimited on users;
alter user SEGURIDAD            quota unlimited on users;
alter user AUDITORIA            quota unlimited on users;
alter user UTEC                         quota unlimited on users;
alter user TIMETABLE            quota unlimited on users;
alter user MATRICULA            quota unlimited on users;
alter user PREMATRICULA                 quota unlimited on users;
alter user CALENDAR             quota unlimited on users;
alter user FINANZAS             quota unlimited on users;
alter user EGRESADO             quota unlimited on users;
alter user TRAMITE    quota unlimited on users;
alter user RESERVA quota unlimited on users;

GRANT DBA TO TIMETABLE;
GRANT DBA TO UTEC;
GRANT DBA TO CALENDAR;
GRANT DBA TO TRAMITE;
GRANT DBA TO WORKFLOW;


-- import permissions
grant create session, create table to UTEC;
grant read, write on directory data_pump_dir to UTEC;
grant execute on dbms_datapump to UTEC;

DECLARE
  ROLE_NAME VARCHAR2(300) := 'READ_ONLY';
  V_ROLE varchar2(50);
BEGIN

        dbms_output.put_line('DROP/CREATE ROLES');
        dbms_output.put_line('----------------');

        BEGIN
          SELECT ROLE INTO V_ROLE FROM DBA_ROLES WHERE ROLE = ROLE_NAME;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          V_ROLE := NULL;
      dbms_output.put_line('ROLE DOES NOT EXIST');
        END;

        IF V_ROLE IS NOT NULL THEN
          execute immediate 'DROP ROLE ' || ROLE_NAME;
          dbms_output.put_line('ROLE DROPED');
        END IF;

        IF V_ROLE IS NULL THEN
          execute immediate 'CREATE ROLE ' || ROLE_NAME;
    dbms_output.put_line('ROLE CREATED');
          execute immediate ' grant create session, select any table, select any dictionary to  ' || ROLE_NAME;
    execute immediate 'GRANT ' || ROLE_NAME ||' TO DESARROLLO';
        END IF;

END;
/
