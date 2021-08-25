WHENEVER SQLERROR EXIT 2
SET SERVEROUTPUT ON

declare
  type table_varchar  is table of varchar2(50);
  var_table_varchar  table_varchar;
  V_SID varchar2(10);
  V_SERIAL varchar2(10);
begin

dbms_output.put_line('KILL SESSION UTEC');
dbms_output.put_line('----------------');

  var_table_varchar  := table_varchar('UTEC');
  for elem in 1 .. var_table_varchar.count loop
    dbms_output.put_line(elem || ': ' || var_table_varchar(elem));

    BEGIN
      select SID, SERIAL INTO V_SID, V_SERIAL from v$session WHERE username = var_table_varchar(elem);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      V_USER := NULL;
    END;

    IF V_USER IS NOT NULL THEN
      begin
        rdsadmin.rdsadmin_util.kill(
        sid    => &sid, 
        serial => &serial_number);
       end;
    END IF;

  end loop;
end;
/
