begin
    rdsadmin.rdsadmin_util.kill(
        sid    => sid, 
        serial => serial_number);
end;
/

select 'exec begin  rdsadmin.rdsadmin_util.kill(sid => ' || SID || ',' || 'serial => ' || SERIAL# || ',method => ' || '''IMMEDIATE''' || '); end;' from v$session WHERE username = 'UTEC';

