begin
    rdsadmin.rdsadmin_util.kill(
        sid    => sid, 
        serial => serial_number);
end;
/

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

set pagesize 0
set line 1000
select 'exec begin  rdsadmin.rdsadmin_util.kill(sid => ' || SID || ',' || 'serial => ' || SERIAL# || ',method => ' || '''IMMEDIATE''' || '); end;' from v$session WHERE username = 'UTEC';

