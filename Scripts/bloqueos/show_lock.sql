-----------------------------------------------------------------------------------------------
alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';
SET SERVEROUTPUT ON size 1000000
DECLARE
   w_sid number;
BEGIN
   w_sid := &w_xxsid;
   dbms_output.put_line('Sesion con Lock Hold: ');
   dbms_output.put_line('SPID | OsUser | Username | SID | Serial# | Module | Status | Kill_OS | Last_Call_Mins | Cons.Gets | Maquina | Logon_Time | Action');
   for reg0 in (SELECT p.spid, s.OsUser, s.UserName, s.sid, s.serial#, s.module, s.status, 'kill -9 '||p.spid kill, round(LAST_CALL_ET/60,2) last_call_min, io.CONSISTENT_GETS cg, s.sql_address, s.sql_hash_value, 
                       s.PREV_SQL_ADDR, s.PREV_HASH_VALUE, s.machine, s.Program, to_char(s.Logon_Time,'dd/mm/yyyy hh24:mi:ss') Logon_Time, s.action, s.row_wait_obj#, s.row_wait_file#, s.row_wait_block#, s.row_wait_row#
                  FROM GV$Session s , Gv$process p, GV$sess_io io
                 WHERE p.addr(+)=s.paddr  AND  s.sid = w_sid
                  AND  io.sid = s.sid and s.UserName Is Not Null
               )
   loop
          dbms_output.put_line(reg0.spid || ' |' || reg0.osuser || ' |' || reg0.username || ' |' || reg0.sid || ' |' || reg0.serial# || ' |' || reg0.module || ' |' || reg0.status || ' |' || reg0.last_call_min || ' |' || reg0.cg || ' |' || reg0.machine || ' |' || reg0.logon_time || ' |' || reg0.action);
      dbms_output.put_line('Kill OS     : ' || reg0.kill);
      dbms_output.put_line('SQL Current : @s ' || reg0.sql_address || ' ' || reg0.sql_hash_value);
      dbms_output.put_line('SQL:');
      for reg1 in (SELECT * FROM V$SQLTEXT WHERE Address=reg0.sql_address AND Hash_Value=reg0.sql_hash_value order by piece)
      loop
         dbms_output.put_line('---> ' || reg1.sql_text);
      end loop;
      dbms_output.put_line('SQL Previous: @s ' || reg0.prev_sql_addr || ' ' || reg0.prev_hash_value);
      if (reg0.sql_address != reg0.prev_sql_addr) and (reg0.sql_hash_value != reg0.prev_hash_value) then
         for reg2 in (SELECT * FROM V$SQLTEXT WHERE Address=reg0.prev_sql_addr AND Hash_Value=reg0.prev_hash_value order by piece)
         loop
            dbms_output.put_line('---> ' || reg2.sql_text);
         end loop;               
      end if;
      for reg3 in (select  do.object_name, decode(data_object_id, NULL, NULL, dbms_rowid.rowid_create( 1, data_object_id, reg0.ROW_WAIT_FILE#, reg0.ROW_WAIT_BLOCK#, reg0.ROW_WAIT_ROW#)) row_id
                   from dba_objects do where do.OBJECT_ID = reg0.ROW_WAIT_OBJ#)
      loop
             dbms_output.put_line('Objeto bloqueado: ' || reg3.object_name || ' |' || reg0.row_wait_obj# || ' |' || reg3.row_id);
      end loop;
   end loop;
END;
/
