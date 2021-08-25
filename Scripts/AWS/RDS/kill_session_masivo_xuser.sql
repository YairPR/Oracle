WHENEVER SQLERROR EXIT 2
SET SERVEROUTPUT ON


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
