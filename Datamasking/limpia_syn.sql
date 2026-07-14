set echo off
set feedback on
set verify off
set serveroutput on size unlimited
set linesize 220
set pagesize 200
set define on

Rem =========================================================
Rem limpia_syn.sql
Rem
Rem Uso:
Rem   @limpia_syn USUARIO
Rem
Rem Elimina sinonimos privados del esquema indicado
Rem que apuntan a ASTSYSADMIN (DATAMASKING)
Rem
Rem Requiere: privilegios DBA
Rem =========================================================

define p_usuario = '&1'

declare
    v_usuario_param varchar2(128) := upper(trim('&&p_usuario'));

    v_total number := 0;
    v_ok    number := 0;
    v_err   number := 0;

    procedure drop_syn(p_owner varchar2, p_syn varchar2) is
        v_sql varchar2(1000);
    begin
        v_sql :=
            'drop synonym ' ||
            dbms_assert.simple_sql_name(p_owner) || '.' ||
            dbms_assert.simple_sql_name(p_syn);

        execute immediate v_sql;

        dbms_output.put_line('OK   -> ' || p_owner || '.' || p_syn);
        v_ok := v_ok + 1;

    exception
        when others then
            dbms_output.put_line(
                'ERR  -> ' || p_owner || '.' || p_syn ||
                ' => ' || sqlerrm
            );
            v_err := v_err + 1;
    end;

begin
    if v_usuario_param is null then
        raise_application_error(-20001,
            'Debe indicar el usuario. Uso: @limpia_syn USUARIO');
    end if;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Limpieza de sinonimos DATAMASKING');
    dbms_output.put_line('Usuario destino : ' || v_usuario_param);
    dbms_output.put_line('Origen          : ASTSYSADMIN');
    dbms_output.put_line('=========================================');

    for r in (
        select synonym_name
        from dba_synonyms
        where owner = v_usuario_param
          and table_owner = 'ASTSYSADMIN'
          and (
                 synonym_name like 'TDM\_%' escape '\'
              or synonym_name like 'PKG\_DM\_%' escape '\'
              or synonym_name like 'SEQ\_DM\_%' escape '\'
              or synonym_name like 'FN\_DM\_%'  escape '\'
              or synonym_name like 'PRC\_DM\_%' escape '\'
          )
        order by synonym_name
    ) loop
        v_total := v_total + 1;
        drop_syn(v_usuario_param, r.synonym_name);
    end loop;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen');
    dbms_output.put_line('Total detectados : ' || v_total);
    dbms_output.put_line('Eliminados OK    : ' || v_ok);
    dbms_output.put_line('Con error        : ' || v_err);
    dbms_output.put_line('=========================================');

end;
/

prompt
prompt =========================================
prompt Validacion final
prompt =========================================

column synonym_name format a35
column table_owner  format a20
column table_name   format a35

select synonym_name,
       table_owner,
       table_name
from dba_synonyms
where owner = upper('&&p_usuario')
  and table_owner = 'ASTSYSADMIN'
order by synonym_name;

undefine 1
undefine p_usuario