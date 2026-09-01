set serveroutput on size unlimited
set feedback off
set verify off

define ESQUEMA = '&1'

declare
  v_esquema varchar2(128) := upper(trim('&ESQUEMA'));
  l_cnt_ini number := 0;
  l_cnt_fin number := 0;
  l_invalid_count number := 9999;
  l_prev_invalid_count number := 9999;
  l_sql varchar2(1000);
begin
  dbms_output.put_line('==============================================================================');
  dbms_output.put_line('INICIO RECOMPILACION DE OBJETOS EN EL ESQUEMA: ' || v_esquema);
  dbms_output.put_line('==============================================================================');

  select count(*) into l_cnt_ini
    from dba_objects
   where owner = v_esquema
     and status = 'INVALID';

  dbms_output.put_line('Objetos INVALID iniciales: ' || l_cnt_ini);

  if l_cnt_ini > 0 then
    loop
      select count(*) into l_invalid_count
        from dba_objects
       where owner = v_esquema
         and status = 'INVALID';
         
      exit when l_invalid_count = 0 or l_invalid_count = l_prev_invalid_count;
      l_prev_invalid_count := l_invalid_count;
      
      for r in (
        select object_type, object_name
          from dba_objects
         where owner = v_esquema
           and status = 'INVALID'
         order by case object_type
                    when 'PACKAGE' then 1
                    when 'TYPE' then 2
                    when 'VIEW' then 3
                    when 'PACKAGE BODY' then 4
                    when 'PROCEDURE' then 5
                    when 'FUNCTION' then 6
                    when 'TRIGGER' then 7
                    else 8
                  end, object_name
      ) loop
        begin
          if r.object_type = 'PACKAGE BODY' then
            l_sql := 'ALTER PACKAGE "'||v_esquema||'"."'||r.object_name||'" COMPILE BODY';
          elsif r.object_type = 'TYPE BODY' then
            l_sql := 'ALTER TYPE "'||v_esquema||'"."'||r.object_name||'" COMPILE BODY';
          else
            l_sql := 'ALTER '||r.object_type||' "'||v_esquema||'"."'||r.object_name||'" COMPILE';
          end if;
          execute immediate l_sql;
        exception
          when others then
            null;
        end;
      end loop;
    end loop;
  end if;

  select count(*) into l_cnt_fin
    from dba_objects
   where owner = v_esquema
     and status = 'INVALID';

  dbms_output.put_line('Objetos INVALID finales: ' || l_cnt_fin);

  if l_cnt_fin > 0 then
    dbms_output.put_line('------------------------------------------------------------------------------');
    dbms_output.put_line('Objetos que no pudieron ser recompilados:');
    for r_rem in (
      select object_name, object_type
        from dba_objects
       where owner = v_esquema
         and status = 'INVALID'
       order by object_type, object_name
    ) loop
      dbms_output.put_line('-> '||r_rem.object_type||': '||v_esquema||'.'||r_rem.object_name);
      -- Obtener el primer error para este objeto
      for r_err in (
        select line, position, text
          from dba_errors
         where owner = v_esquema
           and name = r_rem.object_name
           and type = r_rem.object_type
           and rownum = 1
      ) loop
        dbms_output.put_line('   [Error en Linea '||r_err.line||', Pos '||r_err.position||']: '||r_err.text);
      end loop;
    end loop;
    dbms_output.put_line('------------------------------------------------------------------------------');
  else
    dbms_output.put_line('Todos los objetos se recompilaron exitosamente.');
  end if;
  dbms_output.put_line('==============================================================================');
end;
/
