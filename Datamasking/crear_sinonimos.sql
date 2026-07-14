set echo off
set feedback on
set verify off
set serveroutput on size unlimited
set linesize 220
set pagesize 200
set define on

Rem =========================================================
Rem crea_sinonimos.sql
Rem
Rem Uso:
Rem   @crea_sinonimos USUARIO
Rem
Rem Crea sinonimos privados para objetos DATAMASKING
Rem del esquema ASTSYSADMIN, detectados dinamicamente.
Rem
Rem Mejoras:
Rem - Crea el sinonimo explicitamente en USUARIO.OBJETO
Rem - Valida que el usuario conectado coincida con el parametro
Rem - Detecta choque con objetos reales del esquema destino
Rem - Reemplaza sinonimos existentes si ya eran sinonimos
Rem =========================================================

define p_usuario = '&1'

declare
    v_usuario_param   varchar2(128) := upper(trim('&&p_usuario'));
    v_usuario_sesion  varchar2(128) := upper(sys_context('USERENV','SESSION_USER'));

    v_total           number := 0;
    v_ok              number := 0;
    v_err             number := 0;
    v_skip            number := 0;

    v_cnt_obj         number := 0;
    v_cnt_syn         number := 0;

    procedure create_syn(
        p_owner varchar2,
        p_obj   varchar2
    ) is
        v_sql varchar2(1000);
    begin
        /*
          Si existe un objeto real con ese nombre en el esquema destino,
          NO se puede crear sinonimo con el mismo nombre.
        */
        select count(*)
          into v_cnt_obj
          from dba_objects
         where owner = p_owner
           and object_name = p_obj
           and object_type <> 'SYNONYM';

        if v_cnt_obj > 0 then
            dbms_output.put_line(
                'SKIP -> ' || p_obj ||
                ' => ya existe objeto real en ' || p_owner
            );
            v_skip := v_skip + 1;
            return;
        end if;

        /*
          Si ya existe un sinonimo, CREATE OR REPLACE lo reemplaza.
          Si no existe nada, lo crea normal.
        */
        v_sql :=
            'create or replace synonym ' ||
            dbms_assert.simple_sql_name(p_owner) || '.' ||
            dbms_assert.simple_sql_name(p_obj)   ||
            ' for ASTSYSADMIN.' ||
            dbms_assert.simple_sql_name(p_obj);

        execute immediate v_sql;

        dbms_output.put_line('OK   -> synonym ' || p_owner || '.' || p_obj);
        v_ok := v_ok + 1;

    exception
        when others then
            dbms_output.put_line(
                'ERR  -> synonym ' || p_owner || '.' || p_obj ||
                ' => ' || sqlerrm
            );
            v_err := v_err + 1;
    end create_syn;

begin
    if v_usuario_param is null then
        raise_application_error(
            -20001,
            'Debe indicar el usuario. Uso: @crea_sinonimos USUARIO'
        );
    end if;

    if v_usuario_param <> v_usuario_sesion then
        raise_application_error(
            -20002,
            'El usuario conectado [' || v_usuario_sesion ||
            '] no coincide con el parametro [' || v_usuario_param || '].'
        );
    end if;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Creacion de sinonimos privados');
    dbms_output.put_line('Usuario destino : ' || v_usuario_param);
    dbms_output.put_line('Esquema origen  : ASTSYSADMIN');
    dbms_output.put_line('=========================================');

    for r in (
        select object_name, object_type
          from dba_objects
         where owner = 'ASTSYSADMIN'
           and object_type in ('TABLE','VIEW','PACKAGE','SEQUENCE','FUNCTION','PROCEDURE')
           and (
                  object_name like 'TDM\_%' escape '\'
               or object_name like 'PKG\_DM\_%' escape '\'
               or object_name like 'SEQ\_DM\_%' escape '\'
               or object_name like 'FN\_DM\_%'  escape '\'
               or object_name like 'PRC\_DM\_%' escape '\'
           )
         order by
           case object_type
             when 'PACKAGE'   then 1
             when 'FUNCTION'  then 2
             when 'PROCEDURE' then 3
             when 'TABLE'     then 4
             when 'VIEW'      then 5
             when 'SEQUENCE'  then 6
             else 99
           end,
           object_name
    ) loop
        v_total := v_total + 1;
        create_syn(v_usuario_param, r.object_name);
    end loop;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen');
    dbms_output.put_line('Total detectados : ' || v_total);
    dbms_output.put_line('Creados OK       : ' || v_ok);
    dbms_output.put_line('Saltados         : ' || v_skip);
    dbms_output.put_line('Con error        : ' || v_err);
    dbms_output.put_line('Proceso finalizado');
    dbms_output.put_line('=========================================');
end;
/

prompt
prompt =========================================
prompt Validacion de sinonimos creados
prompt =========================================

column owner        format a15
column synonym_name format a35
column table_owner  format a20
column table_name   format a35

select owner,synonym_name,
       table_owner,
       table_name
  from dba_synonyms
 where owner = upper('&&p_usuario')
   and table_owner = 'ASTSYSADMIN'
   and (
          synonym_name like 'TDM\_%' escape '\'
       or synonym_name like 'PKG\_DM\_%' escape '\'
       or synonym_name like 'SEQ\_DM\_%' escape '\'
       or synonym_name like 'FN\_DM\_%'  escape '\'
       or synonym_name like 'PRC\_DM\_%' escape '\'
   )
 order by synonym_name;

undefine 1
undefine p_usuario