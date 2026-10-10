set serveroutput on size unlimited
set feedback on
set verify off

prompt =========================================================
prompt LIMPIEZA TOTAL DESCUBRIMIENTO + ENMASCARAMIENTO
prompt =========================================================
Rem
Rem Este script borra TODO lo que crea 99_install_datamasking.sql en el esquema del
Rem motor: 5 paquetes, 17 tablas (con sus indices y restricciones), 9 secuencias y el
Rem rol ROL_DATAMASKING, mas las tareas DBMS_PARALLEL_EXECUTE huerfanas (TDM_*) que
Rem el motor deja en el diccionario del esquema. Al final informa si queda algo.
Rem
Rem Requiere un usuario DBA (borra un rol y consulta DBA_*). El esquema del motor se
Rem detecta igual que en el instalador (ASTSYSADMIN o ACC_ADMIN, el que exista).
Rem
Rem NO se revierten a proposito (son privilegios, no objetos del motor; pueden servir
Rem a otras cosas y el instalador los vuelve a conceder sin error):
Rem   - SELECT ANY DICTIONARY y EXECUTE ON SYS.DBMS_CRYPTO al esquema del motor
Rem   - sinonimos privados de cada DBA (crea_sinonimos.sql): quedan colgando hasta
Rem     reinstalar y vuelven a resolver solos
Rem   - la job_class opcional JC_DATAMASKING y su servicio RAC (anexo de 99)
Rem Dejan de ser validos los GRANT ROL_DATAMASKING de cada DBA (se pierden con el
Rem rol): 99 seccion 3.1 los vuelve a conceder.
Rem
Rem Borrado por orden de dependencia: paquetes -> tablas hijas -> tablas padre ->
Rem secuencias -> rol. Los PURGE evitan dejar los objetos en la papelera.

Rem ---------------------------------------------------------------
Rem 0) ESQUEMA DEL MOTOR (deteccion automatica, sin variables de sustitucion)
Rem ===============================================================

declare
  l_esquema dba_users.username%type;
begin
  select username into l_esquema
    from (select username from dba_users
           where username in ('ASTSYSADMIN','ACC_ADMIN')
           order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
   where rownum = 1;
  execute immediate 'alter session set current_schema = ' || l_esquema;
  dbms_output.put_line('Esquema del motor: ' || l_esquema);
exception
  when no_data_found then
    raise_application_error(-20001, 'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS: no hay motor que desinstalar.');
end;
/

declare
  l_esquema varchar2(128) := sys_context('USERENV','CURRENT_SCHEMA');

  procedure proc_drop(p_sql varchar2) is
  begin
    dbms_output.put_line('Intentando: ' || p_sql);
    execute immediate p_sql;
    dbms_output.put_line('OK');
  exception
    when others then
      dbms_output.put_line('ERROR: ' || sqlerrm);
  end;

  -- Tareas DBMS_PARALLEL_EXECUTE del motor (TDM_<hash>). Sobreviven al borrado de las
  -- tablas y a la recarga del esquema; si quedan, la siguiente corrida real las detecta
  -- como OBSOLETA y aborta con ORA-20331. ADM_DROP_TASK exige el rol
  -- ADM_PARALLEL_EXECUTE_TASK (no viene en DBA); si falta, se avisa y se sigue.
  procedure proc_drop_tareas is
    l_cur  sys_refcursor;
    l_task varchar2(128);
    l_n    number := 0;
  begin
    open l_cur for
      'select task_name from dba_parallel_execute_tasks ' ||
      ' where task_owner = :o and task_name like ''TDM\_%'' escape ''\'' order by task_name'
      using l_esquema;
    loop
      fetch l_cur into l_task;
      exit when l_cur%notfound;
      l_n := l_n + 1;
      dbms_output.put_line('Intentando: adm_drop_task ' || l_esquema || '.' || l_task);
      begin
        execute immediate
          'begin dbms_parallel_execute.adm_drop_task(task_owner => :o, task_name => :t); end;'
          using l_esquema, l_task;
        dbms_output.put_line('OK');
      exception
        when others then
          dbms_output.put_line('ERROR: ' || sqlerrm ||
            ' (falta el rol ADM_PARALLEL_EXECUTE_TASK, o la tarea sigue en ejecucion)');
      end;
    end loop;
    close l_cur;
    if l_n = 0 then
      dbms_output.put_line('Sin tareas DBMS_PARALLEL_EXECUTE huerfanas del motor.');
    end if;
  exception
    when others then
      dbms_output.put_line('ERROR al revisar tareas paralelas: ' || sqlerrm);
  end;
begin

  --------------------------------------------------------------------------
  -- 1) TAREAS PARALELAS HUERFANAS
  --------------------------------------------------------------------------
  proc_drop_tareas;

  --------------------------------------------------------------------------
  -- 2) PAQUETES
  --------------------------------------------------------------------------
  proc_drop('drop package pkg_dm_export');
  proc_drop('drop package pkg_dm_enmascarar');
  proc_drop('drop package pkg_dm_descubrimiento');
  proc_drop('drop package pkg_dm_func_mask');
  proc_drop('drop package pkg_dm_trazabilidad');

  --------------------------------------------------------------------------
  -- 3) TABLAS HIJAS DE ENMASCARAMIENTO
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_mask_trace cascade constraints purge');
  proc_drop('drop table tdm_mask_dep_estado cascade constraints purge');
  proc_drop('drop table tdm_mask_relacion_sync cascade constraints purge');
  proc_drop('drop table tdm_mask_regla_esp cascade constraints purge');
  proc_drop('drop table tdm_mask_solicitud cascade constraints purge');
  proc_drop('drop table tdm_secreto cascade constraints purge');
  proc_drop('drop table tdm_parametro cascade constraints purge');

  --------------------------------------------------------------------------
  -- 4) TABLAS HIJAS DE DESCUBRIMIENTO
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_dependencia_final cascade constraints purge');
  proc_drop('drop table tdm_columna_final cascade constraints purge');
  proc_drop('drop table tdm_dependencia_hist cascade constraints purge');
  proc_drop('drop table tdm_columna_hist cascade constraints purge');
  proc_drop('drop table tdm_ejecucion_scope cascade constraints purge');
  proc_drop('drop table tdm_ejecucion_error cascade constraints purge');

  --------------------------------------------------------------------------
  -- 5) TABLAS INDEPENDIENTES
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_objeto_ctrl cascade constraints purge');
  proc_drop('drop table tdm_excepcion_col cascade constraints purge');
  proc_drop('drop table tdm_regla cascade constraints purge');

  --------------------------------------------------------------------------
  -- 6) TABLA PADRE
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_ejecucion cascade constraints purge');

  --------------------------------------------------------------------------
  -- 7) SECUENCIAS MASKING
  --------------------------------------------------------------------------
  proc_drop('drop sequence seq_dm_mask_trace');
  proc_drop('drop sequence seq_dm_mask_relacion_sync');
  proc_drop('drop sequence seq_dm_mask_regla_esp');
  proc_drop('drop sequence seq_dm_mask_solicitud');

  --------------------------------------------------------------------------
  -- 8) SECUENCIAS DISCOVERY
  --------------------------------------------------------------------------
  proc_drop('drop sequence seq_dm_dependencia_hist');
  proc_drop('drop sequence seq_dm_columna_hist');
  proc_drop('drop sequence seq_dm_ejecucion_scope');
  proc_drop('drop sequence seq_dm_regla');
  proc_drop('drop sequence seq_dm_ejecucion');

  --------------------------------------------------------------------------
  -- 9) ROL
  --------------------------------------------------------------------------
  proc_drop('drop role ROL_DATAMASKING');
end;
/

Rem ---------------------------------------------------------------
Rem 10) VERIFICACION: no debe quedar ningun objeto del motor
Rem ===============================================================

declare
  l_esquema varchar2(128) := sys_context('USERENV','CURRENT_SCHEMA');
  l_cur     sys_refcursor;
  l_tipo    varchar2(30);
  l_obj     varchar2(128);
  l_n       number := 0;
begin
  open l_cur for
    'select object_type, object_name from dba_objects ' ||
    ' where owner = :o and (object_name like ''TDM\_%'' escape ''\'' ' ||
    '    or object_name like ''PKG\_DM\_%'' escape ''\'' ' ||
    '    or object_name like ''SEQ\_DM\_%'' escape ''\'') ' ||
    ' order by object_type, object_name'
    using l_esquema;
  loop
    fetch l_cur into l_tipo, l_obj;
    exit when l_cur%notfound;
    l_n := l_n + 1;
    dbms_output.put_line('REMANENTE: ' || l_tipo || ' ' || l_esquema || '.' || l_obj);
  end loop;
  close l_cur;
  if l_n = 0 then
    dbms_output.put_line('VERIFICACION OK: no queda ningun objeto TDM_% / PKG_DM_% / SEQ_DM_% en ' || l_esquema);
  else
    dbms_output.put_line('ATENCION: quedan ' || l_n || ' objetos; revise los ERROR de arriba antes de reinstalar.');
  end if;

  select count(*) into l_n from dba_roles where role = 'ROL_DATAMASKING';
  if l_n > 0 then
    dbms_output.put_line('ATENCION: el rol ROL_DATAMASKING sigue existiendo.');
  end if;
end;
/
