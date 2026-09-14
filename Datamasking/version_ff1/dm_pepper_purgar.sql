undefine V_ARG1
undefine V_EJEC_ID

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 220
set pagesize 200
set tab off
alter session set current_schema = ASTSYSADMIN;

Rem =========================================================
Rem dm_pepper_purgar.sql  (VERSION FF1)
Rem
Rem Uso:
Rem   @dm_pepper_purgar EJECUCION_ID
Rem
Rem Elimina la semilla efimera de ESA campana (tdm_secreto.clave =
Rem 'PEPPER_MASK:'||ejecucion_id). Ejecutar como PASO FINAL, despues del
Rem enmascarado, la validacion y el export. Con el pepper borrado el dato
Rem enmascarado deja de ser reversible (no hay vuelta atras salvo reimportar PRO).
Rem =========================================================

prompt Purga de semilla efimera (pepper).....

column c_ejec new_value V_EJEC_ID noprint
select trim('&1') as c_ejec from dual;

declare
    v_tok        varchar2(4000) := trim('&&V_EJEC_ID');
    v_ejec       number;
    v_esquema    varchar2(128);
    v_existe_ej  number := 0;
    v_existe_pep number := 0;
    v_clave      varchar2(64);
begin
    -- 1) Validar parametro numerico
    if v_tok is null or not regexp_like(v_tok, '^[0-9]+$') then
        raise_application_error(-20401, 'Uso: @dm_pepper_purgar EJECUCION_ID');
    end if;
    v_ejec  := to_number(v_tok);
    v_clave := 'PEPPER_MASK:'||to_char(v_ejec);

    -- 2) Confirmar que la ejecucion existe (evita borrados por id equivocado)
    begin
        select esquema_objetivo into v_esquema
          from tdm_ejecucion
         where ejecucion_id = v_ejec;
        v_existe_ej := 1;
    exception
        when no_data_found then
            v_existe_ej := 0;
    end;

    if v_existe_ej = 0 then
        dbms_output.put_line('AVISO: no existe la ejecucion_id '||v_ejec||' en TDM_EJECUCION.');
        dbms_output.put_line('Se intentara purgar la clave '||v_clave||' de todas formas.');
    end if;

    -- 3) Estado previo del pepper
    select count(*) into v_existe_pep from tdm_secreto where clave = v_clave;

    -- 4) Purga (procedimiento oficial del paquete)
    pkg_dm_enmascarar.p_dm_pepper_purgar(p_ejecucion_id => v_ejec);

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Purga de pepper');
    dbms_output.put_line('Ejecucion_id : '||v_ejec);
    if v_existe_ej = 1 then
        dbms_output.put_line('Esquema      : '||v_esquema);
    end if;
    dbms_output.put_line('Clave        : '||v_clave);
    if v_existe_pep = 0 then
        dbms_output.put_line('Estado       : la semilla ya no existia (nada que borrar).');
    else
        dbms_output.put_line('Estado       : semilla eliminada. El dato enmascarado ya no es reversible.');
    end if;
    dbms_output.put_line('=========================================');
end;
/

Rem Comprobacion final: no debe devolver filas
column clave format a40
select clave from tdm_secreto where clave = 'PEPPER_MASK:'||'&&V_EJEC_ID';

undefine 1
undefine V_ARG1
undefine V_EJEC_ID
