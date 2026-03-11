SET SERVEROUTPUT ON
SET TIMING ON

create table 
   DSM$DB_DSG_DDLS_E 
   (object_type varchar2(20), 
   object_name varchar2(128), 
   object_owner varchar2(128), 
   table_name varchar2(128), 
   otype varchar2(27), 
   validated varchar2(13), 
   object_ddl clob) 
/

create or replace procedure DSM$DSG_STORE_DDL
(object_type in varchar2,
 object_name in varchar2, 
 object_owner in varchar2, 
 table_name in varchar2, 
 otype in varchar2, 
 validated in varchar2, 
 object_ddl in clob) 
 is 
 v_cursor binary_integer; 
 no_rows integer; 
 ins_sql varchar2(32767); 
begin 
ins_sql:='insert into DSM$DB_DSG_DDLS_E'||
 ' values (:obj_type,' ||
 ':obj_name, :obj_owner, :tbl_name, '||
 ' :o_type, :validated, :obj_ddl)';
v_cursor := dbms_sql.open_cursor;
dbms_sql.parse(v_cursor, ins_sql, dbms_sql.native);
dbms_sql.bind_variable(v_cursor, ':obj_type', object_type);
dbms_sql.bind_variable(v_cursor, ':obj_name', object_name);
dbms_sql.bind_variable(v_cursor, ':obj_owner', object_owner);
dbms_sql.bind_variable(v_cursor, ':tbl_name', table_name);
dbms_sql.bind_variable(v_cursor, ':o_type', otype);
dbms_sql.bind_variable(v_cursor, ':validated', validated);
dbms_sql.bind_variable(v_cursor, ':obj_ddl', object_ddl);
no_rows := dbms_sql.execute(v_cursor);
dbms_sql.close_cursor(v_cursor);
exception 
  when others then
    dbms_sql.close_cursor(v_cursor);
    raise;
end DSM$DSG_STORE_DDL;
/
show errors;

create or replace function DSM$IS_QUEUETABLE(owner in varchar2,
                                              table_name in varchar2)
return boolean
AUTHID CURRENT_USER
as
 query varchar2(32767);
 flag number;
begin
 query := 'select count(*) ' ||
          'from dba_queue_tables ' ||
          'where owner = ''' || owner || '''' ||
          ' and queue_table = ''' || table_name || '''';
 execute immediate query into flag;
 if (flag = 0) then
   return false;
 else
   return true;
 end if;
 end DSM$IS_QUEUETABLE;
/
show errors;

create or replace procedure DSM$MANAGE_TRIGGERS(l_owner varchar2,
                                                opcode integer)
AUTHID CURRENT_USER
as
 query_text varchar2(32767);
 query_text1 varchar2(32767);
 trigger_name varchar2(128);
 trigger_owner varchar2(128);
 type cursor is ref cursor;
 c1 cursor;
begin
 if opcode = 1 then
    query_text1 := 'select trigger_name' ||
                  ' from dba_triggers ' ||
                  'where owner = ''' || 
                  'l_owner || '''||
                  'and status = ''ENABLED''';
    open c1 for query_text1;
    loop
    fetch c1 into trigger_name;
    exit when c1%notfound;
    query_text := 'alter trigger ' ||
                    l_owner || '.' ||
          trigger_name || ' disable';
    begin
      execute immediate query_text;
    exception
    when others then
       dbms_output.put_line(query_text||' '||sqlerrm(sqlcode));
    end;
    DSM$DSG_STORE_DDL('TRIGGER',
                      trigger_name, l_owner, null,null,
                      null, null);
    end loop;
    close c1;
 elsif opcode = 2 then 
   query_text1 := 'select object_name, '||
                  'object_owner from  DSM$DB_DSG_DDLS_E '||
                  'where object_type =''TRIGGER'' ';
   open c1 for query_text1;
   loop
   fetch c1 into trigger_name, trigger_owner;
   exit when c1%notfound;
   query_text := 'alter trigger ' || trigger_owner || '.' ||
                   trigger_name || ' enable';
   begin
     execute immediate query_text;
   exception
   when others then
      dbms_output.put_line(query_text||' '||sqlerrm(sqlcode));
   end;
   end loop;
   close c1;
 end if;
end DSM$MANAGE_TRIGGERS;
/
show errors;

create or replace procedure DSM$MANAGE_CONSTRAINTS(l_owner varchar2,
                                                   opcode integer,
                                                   is_pri boolean)
AUTHID CURRENT_USER
as
 query_text varchar2(32767);
 query_text1 varchar2(32767);
 query_text2 varchar2(32767);
 iot_type varchar2(12);
 object_owner varchar2(128);
 table_name varchar2(128);
 constraint_name varchar2(128);
 otype varchar2(27);
 validated varchar2(13);
 type cursor is ref cursor;
 c1 cursor;
 c2 cursor;
begin
if opcode = 1 then
 query_text1 := 'select table_name, iot_type ' ||
                'from dba_tables ' ||
                'where owner = '''  || l_owner || '''' ||
		       ' and table_name not like ''AQ$%''';
 open c1 for query_text1;
 loop
   fetch c1 into table_name, iot_type;
   exit when c1%notfound;
   if(not (DSM$IS_QUEUETABLE(l_owner, table_name))) then
     if(is_pri = TRUE) then
       query_text2 := 'select constraint_name, constraint_type, validated ' ||
                      'from dba_constraints ' ||
                      'where owner = ''' || l_owner || '''' ||
                      ' and table_name = ''' || table_name || '''' ||
                      ' and constraint_type in (''P'', ''U'')'||
                      ' and status=''ENABLED''';
       open c2 for query_text2;
       loop
         fetch c2 into constraint_name, otype, validated;
         exit when c2%notfound;
         if iot_type is null then
           query_text := 'alter table ' || l_owner || '.' || table_name ||
                         ' disable constraint ' || constraint_name;
           begin
             execute immediate query_text;
           exception
             when others then
               dbms_output.put_line(query_text || ' ' || sqlerrm(sqlcode));
           end;
           DSM$DSG_STORE_DDL('CONSTRAINT',
                             constraint_name, l_owner, table_name, otype,
                             validated, null);
         end if;
         query_text := null;
       end loop;
       close c2;
     else
       query_text2 := 'select constraint_name, constraint_type, validated ' ||
                      'from dba_constraints ' ||
                      'where owner = ''' || l_owner || '''' ||
                      ' and table_name = ''' || table_name || '''' ||
                      ' and constraint_type not in (''P'', ''U'')'||
                      ' and status=''ENABLED''';
       open c2 for query_text2;
       loop
         fetch c2 into constraint_name, otype, validated;
         exit when c2%notfound;
           query_text := 'alter table ' || l_owner || '.' || table_name ||
                         ' disable constraint ' || constraint_name;
         begin
           execute immediate query_text;
         exception
           when others then
             dbms_output.put_line(query_text || ' ' || sqlerrm(sqlcode));
         end;
           DSM$DSG_STORE_DDL('CONSTRAINT',
                             constraint_name, l_owner, table_name, otype,
                             validated, null);
       end loop;
       close c2;
     end if;
   end if;
 end loop;
 close c1;
elsif opcode = 2 then
     if(is_pri = TRUE) then
       query_text2 := 'select object_name, object_owner, table_name, ' ||
                      'validated from DSM$DB_DSG_DDLS_E ' ||
                      'where object_type=''CONSTRAINT''' ||
                      ' and otype in (''P'', ''U'')';
       open c2 for query_text2;
       loop
         fetch c2 into constraint_name, object_owner, table_name, validated;
         exit when c2%notfound;
           query_text := 'alter table ' || object_owner || '.' || table_name ||
                         ' enable novalidate constraint ' || constraint_name;
           begin
             execute immediate query_text;
             if validated = 'VALIDATED' then 
           query_text := 'alter table ' || object_owner || '.' || table_name ||
                         ' modify constraint ' || constraint_name ||
                         ' validate';
              execute immediate query_text;
             end if;
           exception
             when others then
               dbms_output.put_line(query_text || ' ' || sqlerrm(sqlcode));
           end;
         query_text := null;
       end loop;
       close c2;
     else
       query_text2 := 'select object_name, object_owner, table_name, ' ||
                      'validated from DSM$DB_DSG_DDLS_E ' ||
                      'where object_type=''CONSTRAINT''' ||
                      ' and otype not in (''P'', ''U'')';
       open c2 for query_text2;
       loop
         fetch c2 into constraint_name, object_owner, table_name, validated;
         exit when c2%notfound;
           query_text := 'alter table ' || object_owner || '.' || table_name ||
                         ' enable novalidate constraint ' || constraint_name;
           begin
             execute immediate query_text;
             if validated = 'VALIDATED' then 
           query_text := 'alter table ' || object_owner || '.' || table_name ||
                         ' modify constraint ' || constraint_name ||
                         ' validate';
              execute immediate query_text;
             end if;
           exception
             when others then
               dbms_output.put_line(query_text || ' ' || sqlerrm(sqlcode));
           end;
         query_text := null;
       end loop;
       close c2;
     end if;
end if;
end DSM$MANAGE_CONSTRAINTS;
/
show errors;

define user_choice=2
define dump_dir_object=EPR_DM
prompt Chose the state of the schemas from below:
prompt 1 - None of the schemas exist.
prompt 2 - A part or all of the schemas exist.
prompt 3 - The schemas exist with complete metadata but no data.
accept user_choice number prompt 'enter choice (1/2/3): ';
accept dump_dir_object char prompt 'Enter directory object name: ';
declare
 h number;
 sts ku$_Status;
 le ku$_LogEntry;
 job_state varchar2(30);
 ind number;
 user_choice number := &user_choice;
 type schema_list is table of varchar2(128);
 schemas schema_list := schema_list();
 type tablespace_list is table of varchar2(30);
 tablespaces tablespace_list := tablespace_list();
 default_tablespace varchar2(30);
 tablespace_flag integer;
 dump_name varchar2(255) := 'EXPDAT%U.DMP';
 l_index  pls_integer := 1;
 l_comma_index pls_integer;
 dump_dir varchar2(200) := '&dump_dir_object';
 user_missing exception;
 pragma exception_init(user_missing, -01918);
begin
 schemas.extend;
 schemas(schemas.last) := 'DM_PCSS_OWN';

 tablespaces.extend;
 tablespaces(tablespaces.last) := 'PCSS_DAT';
 tablespaces.extend;
 tablespaces(tablespaces.last) := 'PCSS_IDX';
 tablespaces.extend;
 tablespaces(tablespaces.last) := 'PCSS_LOB';

 execute immediate 'select default_tablespace from user_users' into default_tablespace;

 if user_choice < 1 or user_choice > 3 then
   dbms_output.put_line('Invalid choice for state of schemas, going with option 2');
   user_choice := 2;
 end if;

 if user_choice = 2 then
   for ind in 1..schemas.last loop
     begin
       execute immediate 'drop user ' || schemas(ind) || ' cascade';
     exception
       when user_missing then
         dbms_output.put_line('user ' || schemas(ind) || ' already dropped or missing');
     end;
   end loop;
     dbms_output.put_line('schemas dropped');
 end if;

 if user_choice = 3 then
   begin
     for ind in 1..schemas.last loop
       DSM$MANAGE_CONSTRAINTS(schemas(ind), 1, FALSE);
     end loop;
     for ind in 1..schemas.last loop
       DSM$MANAGE_CONSTRAINTS(schemas(ind), 1, TRUE);
     end loop;
	    commit;
     dbms_output.put_line('constraints disabled');
   end;

   begin
     for ind in 1..schemas.last loop
       DSM$MANAGE_TRIGGERS(schemas(ind), 1);
     end loop;
     commit;
     dbms_output.put_line('triggers disabled');
   end;
 end if;

 begin
   h := dbms_datapump.open('IMPORT', 'FULL');
   if instr(dump_name, ',') <> 0 then
      dump_name := replace(rtrim(dump_name,','),' ','');
      loop
          l_comma_index := instr( dump_name||',' , ',', l_index);
          exit when l_comma_index = 0;
          dbms_datapump.add_file(h, 
                        substr(dump_name, l_index, l_comma_index - l_index),
                        dump_dir, null, 1);
          l_index := l_comma_index + 1;
      end loop;
   else
      dbms_datapump.add_file(h, dump_name, dump_dir, null, 1);
   end if;
   dbms_datapump.add_file(h, 'tdm_import.log', dump_dir, null, 3);
   if user_choice = 3 then
     dbms_datapump.set_parameter(h, 'INCLUDE_METADATA', 0);
   end if;
--dbms_datapump.set_parameter(h, 'TABLE_EXISTS_ACTION', 'REPLACE');

   for ind in 1..tablespaces.last loop
     execute immediate 'select count(*) ' ||
                       'from dba_tablespaces ' ||
                       'where tablespace_name = ''' ||
                       tablespaces(ind) || '''' into tablespace_flag;
     if tablespace_flag = 0 then
       dbms_datapump.metadata_remap(h, 'REMAP_TABLESPACE', tablespaces(ind), default_tablespace);
     end if;
   end loop;

   dbms_datapump.metadata_transform(h, 'STORAGE', 1, 'TABLE');

   dbms_datapump.start_job(h);
   job_state := 'UNDEFINED';
   while (job_state != 'COMPLETED') and (job_state != 'STOPPED') loop
     dbms_datapump.get_status(h, 13, -1, job_state, sts);
   end loop;
   dbms_datapump.detach(h);
 exception
   when others then
     dbms_datapump.get_status(h, 8, 0, job_state, sts);
     le := sts.error;
     ind := le.first;
     while ind is not null loop
       dbms_output.put_line(le(ind).logText);
       ind := le.next(ind);
     end loop;
     dbms_datapump.detach(h);
 end;

 if user_choice = 3 then
   begin
     for ind in 1..schemas.last loop
       DSM$MANAGE_CONSTRAINTS(schemas(ind), 2, TRUE);
     end loop;
     for ind in 1..schemas.last loop
       DSM$MANAGE_CONSTRAINTS(schemas(ind), 2, FALSE);
     end loop;
     commit;
     dbms_output.put_line('constraints enabled');
   end;

   begin
     for ind in 1..schemas.last loop
       DSM$MANAGE_TRIGGERS(schemas(ind), 2);
     end loop;
     commit;
     dbms_output.put_line('triggers enabled');
   end;
 end if;

end;
/

DROP TABLE DSM$DB_DSG_DDLS_E PURGE;
DROP PROCEDURE DSM$DSG_STORE_DDL;
DROP FUNCTION DSM$IS_QUEUETABLE;
DROP PROCEDURE DSM$MANAGE_CONSTRAINTS;
DROP PROCEDURE DSM$MANAGE_TRIGGERS;
