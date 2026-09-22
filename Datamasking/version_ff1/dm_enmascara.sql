undefine V_ARG1
undefine V_ARG2
undefine V_EJEC_ID
undefine V_SOL_ID

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 220
set pagesize 200
set trimspool on
set tab off
alter session set current_schema = ASTSYSADMIN;

column c_estado         format a18
column c_fase           format a25
column c_fecha          format a19
column c_detalle        format a100 word_wrapped
column c_objeto         format a45
column c_paso           format a35
column c_total          format 999999999
column c_trace_id       format 999999999
column c_nivel          format a8
column c_tipo_objeto    format a12
column c_owner          format a30
column c_table          format a35
column c_objname        format a35
column c_identificador  format a35
column c_column_name    format a35
column c_table_name     format a35

prompt Enmascaramiento en ejecucion.....

set termout off

column "2" new_value 2 noprint
select null as "2" from dual where 1=2;

column final_p1 new_value V_ARG1 noprint
column final_p2 new_value V_ARG2 noprint

select trim('&1') final_p1,
       upper(trim(nvl('&2', '%'))) final_p2
from dual;

set termout on

declare
    v_tok1                  varchar2(4000) := trim('&&V_ARG1');
    v_param                 varchar2(10)   := upper(trim('&&V_ARG2'));

    v_ejecucion_id          number;
    v_esquema               varchar2(128);
    v_en_curso              number := 0;

    v_total_final           number := 0;
    v_total_final_y         number := 0;
    v_total_force_y         number := 0;
    v_total_candidatas      number := 0;
    v_solicitud_id          number := -1;

    v_estado_pre            varchar2(30);
    v_fase_pre              varchar2(30);
    v_fecha_ini_pre         date;
    v_fecha_fin_pre         date;
    v_ultimo_paso_pre       varchar2(4000);
    v_ultimo_objeto_pre     varchar2(4000);
    v_progreso_pre          number;

    v_estado_post           varchar2(30);
    v_fase_post             varchar2(30);
    v_fecha_ini_post        date;
    v_fecha_fin_post        date;
    v_ultimo_paso_post      varchar2(4000);
    v_ultimo_objeto_post    varchar2(4000);
    v_progreso_post         number;

    v_warn_pre_error        varchar2(1) := 'N';
    v_warn_post_error       varchar2(1) := 'N';
    v_cnt_warns             number := 0;
    v_cnt_errs_trace        number := 0;
    v_cnt_errs_log          number := 0;
    v_dep_disabled          number := 0;
    v_dep_enabled           number := 0;

begin
    if v_tok1 is null or not regexp_like(v_tok1, '^[0-9]+$') then
        raise_application_error(-20301,
            'Uso: @dm_enmascara EJECUCION_ID | @dm_enmascara EJECUCION_ID Y');
    end if;

    v_ejecucion_id := to_number(v_tok1);

    if v_param = '%' then
        v_param := 'N';
    end if;

    if v_param not in ('N','Y') then
        raise_application_error(-20303,
            'Parametro invalido. Usar Y para reproceso forzado o vacio para default.');
    end if;

    begin
        select esquema_objetivo,
               estado,
               fase_proceso,
               cast(fecha_inicio as date),
               cast(fecha_fin as date),
               ultimo_paso,
               ultimo_objeto,
               progreso_pct
          into v_esquema,
               v_estado_pre,
               v_fase_pre,
               v_fecha_ini_pre,
               v_fecha_fin_pre,
               v_ultimo_paso_pre,
               v_ultimo_objeto_pre,
               v_progreso_pre
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then
            raise_application_error(-20304,
                'No existe la ejecucion_id ' || v_ejecucion_id || ' en TDM_EJECUCION');
    end;

    if upper(nvl(v_estado_pre,'?')) = 'ERROR' then
        v_warn_pre_error := 'Y';
    end if;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Ejecucion Enmascaramiento');
    dbms_output.put_line('Ejecucion_id  : ' || v_ejecucion_id);
    dbms_output.put_line('Esquema       : ' || v_esquema);
    dbms_output.put_line('Parametro     : ' || case when v_param = 'Y' then 'Y' else '(default)' end);
    dbms_output.put_line('=========================================');

    begin
        select count(*)
          into v_en_curso
          from tdm_mask_solicitud
         where ejecucion_id = v_ejecucion_id
           and estado in ('PENDIENTE','EN_PROCESO','REPROCESANDO');
    exception
        when others then
            v_en_curso := 0;
    end;

    if v_en_curso > 0 then
        raise_application_error(-20305,
            'Ya existe una solicitud de enmascaramiento en curso para la ejecucion ' || v_ejecucion_id);
    end if;

    select count(*)
      into v_total_final
      from tdm_columna_final
     where owner_name = v_esquema;

    if v_total_final = 0 then
        raise_application_error(-20306,
            'No existen columnas en TDM_COLUMNA_FINAL para el esquema ' || v_esquema || '. Ejecute discovery primero.');
    end if;

    select count(*)
      into v_total_final_y
      from tdm_columna_final
     where owner_name = v_esquema
       and enmascarar = 'Y';

    -- FIX 2026-09-20: el motor (pkg_dm_enmascarar.proc_dm_mask_cat, variable
    -- l_has_final) NO exige enmascarar='Y' de forma incondicional: si no hay
    -- NINGUNA columna en TDM_COLUMNA_FINAL con enmascarar='Y' para el
    -- esquema, toma como fuente alterna las columnas con excepcion FORCE
    -- activa en TDM_EXCEPCION_COL (identificador_forz definido y existente
    -- en DBA_TAB_COLUMNS) - es el flujo "FORCE-only" acordado el 17/09
    -- (TDM_COLUMNA_FINAL.enmascarar='N' en todo el esquema, enmascarado
    -- 100% vía excepciones) y ya usado en producción (ejecucion_id=57).
    -- Esta precondicion debe reflejar exactamente esa misma regla de
    -- l_has_final; antes solo miraba enmascarar='Y' y bloqueaba con -20307
    -- un escenario que el motor SI puede procesar.
    if v_total_final_y = 0 then
        select count(*)
          into v_total_force_y
          from tdm_excepcion_col e
         where upper(trim(e.owner_name)) = v_esquema
           and upper(trim(e.activa)) = 'Y'
           and upper(trim(e.accion)) = 'FORCE'
           and e.identificador_forz is not null
           and exists (
             select 1
               from dba_tab_columns c
              where c.owner = upper(trim(e.owner_name))
                and c.table_name = upper(trim(e.table_name))
                and c.column_name = upper(trim(e.column_name))
           );

        if v_total_force_y = 0 then
            raise_application_error(-20307,
                'No existen columnas marcadas para enmascarar (enmascarar=''Y'' en TDM_COLUMNA_FINAL) ' ||
                'ni excepciones FORCE activas y validas en TDM_EXCEPCION_COL para el esquema ' || v_esquema);
        end if;
    end if;

    v_total_candidatas := case when v_total_final_y > 0 then v_total_final_y else v_total_force_y end;

    dbms_output.put_line('Total columnas catalogadas : ' || v_total_final);
    dbms_output.put_line('Columnas con enmascarar=Y  : ' || v_total_final_y);

    if v_total_final_y = 0 then
        dbms_output.put_line('Fuente de enmascarado      : EXCEPCIONES FORCE (' || v_total_force_y ||
                              ' columna(s) - TDM_COLUMNA_FINAL.enmascarar=N en todo el esquema)');
    end if;

    if v_warn_pre_error = 'Y' then
        dbms_output.put_line('ADVERTENCIA: la ejecucion venia previamente en estado ERROR.');
        dbms_output.put_line('Se intentara una nueva ejecucion con los parametros indicados.');
        dbms_output.put_line('-----------------------------------------');
    end if;

    if v_param = 'Y' then
        dbms_output.put_line('Modo: FORZAR / REPROCESO');
        pkg_dm_enmascarar.p_dm_enmascara(
            p_ejecucion_id => v_ejecucion_id,
            p_reproceso    => 'Y',
            p_commit_lote  => 1000
        );
    else
        dbms_output.put_line('Modo: DEFAULT');
        pkg_dm_enmascarar.p_dm_enmascara(
            p_ejecucion_id => v_ejecucion_id,
            p_reproceso    => 'N',
            p_commit_lote  => 1000
        );
    end if;

    begin
        select nvl(max(s.solicitud_id), -1)
          into v_solicitud_id
          from tdm_mask_solicitud s
         where s.ejecucion_id = v_ejecucion_id;
    exception
        when others then
            v_solicitud_id := -1;
    end;

    begin
        select esquema_objetivo,
               estado,
               fase_proceso,
               cast(fecha_inicio as date),
               cast(fecha_fin as date),
               ultimo_paso,
               ultimo_objeto,
               progreso_pct
          into v_esquema,
               v_estado_post,
               v_fase_post,
               v_fecha_ini_post,
               v_fecha_fin_post,
               v_ultimo_paso_post,
               v_ultimo_objeto_post,
               v_progreso_post
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then
            v_estado_post := null;
    end;

    if upper(nvl(v_estado_post,'?')) = 'ERROR' then
        v_warn_post_error := 'Y';
    end if;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen final');
    dbms_output.put_line('Esquema                : ' || v_esquema);
    dbms_output.put_line('Solicitud_id           : ' || case when v_solicitud_id = -1 then '(no encontrada)' else to_char(v_solicitud_id) end);
    dbms_output.put_line('Columnas candidatas    : ' || v_total_candidatas ||
                          case when v_total_final_y = 0 then ' (via excepciones FORCE)' else '' end);

    if v_estado_pre is not null then
        dbms_output.put_line('Estado previo          : ' || v_estado_pre);
    end if;

    if v_estado_post is not null then
        dbms_output.put_line('Estado actual          : ' || v_estado_post);
    end if;

    if v_fecha_ini_post is not null then
        dbms_output.put_line('Inicio ejecucion       : ' || to_char(v_fecha_ini_post, 'dd-mm-yyyy hh24:mi:ss'));
    end if;

    if v_fecha_fin_post is not null then
        dbms_output.put_line('Fin ejecucion          : ' || to_char(v_fecha_fin_post, 'dd-mm-yyyy hh24:mi:ss'));
    end if;

    if v_progreso_post is not null then
        dbms_output.put_line('Progreso %             : ' || v_progreso_post);
    end if;

    if v_ultimo_paso_post is not null then
        dbms_output.put_line('Ultimo paso            : ' || substr(v_ultimo_paso_post,1,200));
    end if;

    if v_ultimo_objeto_post is not null then
        dbms_output.put_line('Ultimo objeto          : ' || substr(v_ultimo_objeto_post,1,200));
    end if;

    if v_warn_post_error = 'Y' then
        dbms_output.put_line('ADVERTENCIA FINAL      : La ejecucion quedo en ERROR. Revisar trazas y errores.');
    end if;

    if v_solicitud_id <> -1 then
        begin
            select count(*)
              into v_cnt_warns
              from tdm_mask_trace
             where solicitud_id = v_solicitud_id
               and nivel = 'WARN';
        exception when others then null;
        end;

        begin
            select count(*)
              into v_cnt_errs_trace
              from tdm_mask_trace
             where solicitud_id = v_solicitud_id
               and nivel = 'ERROR';
        exception when others then null;
        end;

        begin
            select count(*)
              into v_dep_disabled
              from tdm_mask_dep_estado
             where solicitud_id = v_solicitud_id
               and deshabilitado_ok = 'Y';
        exception when others then null;
        end;

        begin
            select count(*)
              into v_dep_enabled
              from tdm_mask_dep_estado
             where solicitud_id = v_solicitud_id
               and habilitado_ok = 'Y';
        exception when others then null;
        end;
    end if;

    begin
        select count(*)
          into v_cnt_errs_log
          from tdm_ejecucion_error
         where ejecucion_id = v_ejecucion_id;
    exception when others then null;
    end;

    dbms_output.put_line('================================================');
	dbms_output.put_line('  ');
    dbms_output.put_line('Resumen de Trazabilidad');
    dbms_output.put_line('Alertas en trace (WARN)  : ' || v_cnt_warns);
    dbms_output.put_line('Errores en trace (ERROR) : ' || v_cnt_errs_trace);
    dbms_output.put_line('Errores en log de fallas : ' || v_cnt_errs_log);
    dbms_output.put_line('Restricciones desactivadas: ' || v_dep_disabled || ' / reactivadas: ' || v_dep_enabled);
    dbms_output.put_line('================================================');
	dbms_output.put_line('  ');
    dbms_output.put_line('Tablas para mas detalle:');
    dbms_output.put_line('  1. TDM_EJECUCION         - Estado macro del proceso');
    dbms_output.put_line('  2. TDM_MASK_SOLICITUD    - Checkpoints y contadores operativos');
    dbms_output.put_line('  3. TDM_EJECUCION_ERROR   - Historial de errores con backtrace PL/SQL');
    dbms_output.put_line('  4. TDM_MASK_TRACE        - Bitacora de eventos paso a paso');
    dbms_output.put_line('  5. TDM_MASK_DEP_ESTADO   - Estado de FKs, indices y triggers');
    dbms_output.put_line('================================================');
end;
/

/*
set termout off
@dm_validar_flujo &V_ESQUEMA_VAL &V_EJEC_ID
*/

undefine 1
undefine 2
undefine V_ARG1
undefine V_ARG2
undefine V_EJEC_ID
undefine V_ESQUEMA_VAL
