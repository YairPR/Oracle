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

Rem --- Esquema del motor: se detecta solo (ASTSYSADMIN o ACC_ADMIN), sin setear nada a mano ---
define esquemaast = '__NO_DETECTADO__'
define tbsast     = '__NO_DETECTADO__'
column v_esquemaast noprint new_value esquemaast
column v_tbsast      noprint new_value tbsast
select username as v_esquemaast, nvl(default_tablespace,username) as v_tbsast
  from (select username, default_tablespace from dba_users
         where username in ('ASTSYSADMIN','ACC_ADMIN')
         order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
 where rownum = 1;
declare
begin
  if upper(trim('&&esquemaast')) = '__NO_DETECTADO__' then
    raise_application_error(-20001,'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
  end if;
end;
/
alter session set current_schema = &&esquemaast;

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

    v_total_tablas_y        number := 0;
    v_total_tablas_force    number := 0;
    v_total_tablas_map      number := 0;

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
    -- FIX 2026-10-02 (hallazgo real, pregunta directa del usuario sobre la
    -- asimetria "desactivadas: 2 / reactivadas: 4" en una ejecucion real sobre
    -- DATAM_ARCA_OWN): habilitado_ok='Y' en TDM_MASK_DEP_ESTADO se marca en DOS
    -- situaciones semanticamente distintas (ver 05_dm_pkg_enmascarar.sql):
    --   1) proc_dm_post_dep la marca tras ejecutar con exito el ENABLE real
    --      (reactivacion autentica de algo que SI se deshabilito).
    --   2) proc_dm_pre_dep la marca de forma preventiva, en el momento del PRE,
    --      para dependencias configuradas en TDM_DEPENDENCIA_FINAL que ya NO
    --      EXISTEN en el diccionario (SKIP_DEP_NOT_FOUND) -- nunca se deshabilitaron,
    --      asi que no necesitan reactivarse, y se marcan "ok" por definicion.
    -- v_dep_enabled contaba TODAS las filas con habilitado_ok='Y' sin distinguir
    -- ambos casos, de modo que dependencias nunca tocadas (por estar obsoletas)
    -- se sumaban como si hubieran sido reactivadas. Se añaden contadores propios
    -- para cada situacion real y se corrige v_dep_enabled para que solo cuente
    -- reactivaciones autenticas (deshabilitado_ok='Y' AND habilitado_ok='Y').
    v_dep_no_hallada        number := 0;
    v_dep_fallo_reactivar   number := 0;

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
        select ora_esquema,
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
     where ora_owner = v_esquema;

    if v_total_final = 0 then
        raise_application_error(-20306,
            'No existen columnas en TDM_COLUMNA_FINAL para el esquema ' || v_esquema || '. Ejecute discovery primero.');
    end if;

    select count(*), count(distinct table_name)
      into v_total_final_y, v_total_tablas_y
      from tdm_columna_final
     where ora_owner = v_esquema
       and enmascarar = 'Y';

    if v_total_final_y = 0 then
        select count(*), count(distinct table_name)
          into v_total_force_y, v_total_tablas_force
          from tdm_excepcion_col e
         where upper(trim(e.ora_owner)) = v_esquema
           and upper(trim(e.activa)) = 'Y'
           and upper(trim(e.accion)) = 'FORCE'
           and e.identificador_forz is not null
           and exists (
             select 1
               from dba_tab_columns c
              where c.owner = upper(trim(e.ora_owner))
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

    v_total_tablas_map := case when v_total_final_y > 0 then v_total_tablas_y else v_total_tablas_force end;

    dbms_output.put_line('Total columnas catalogadas : ' || v_total_final);
    dbms_output.put_line('Columnas con enmascarar=Y  : ' || v_total_final_y);
    dbms_output.put_line('Tablas descubiertas y mapeadas : ' || v_total_tablas_map ||
                          case when v_total_final_y = 0 then ' (via excepciones FORCE)' else '' end);

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
        pkg_dm_enmascarar.proc_dm_enmascaramiento(
            p_ejecucion_id => v_ejecucion_id,
            p_reproceso    => 'Y',
            p_commit_lote  => 1000
        );
    else
        dbms_output.put_line('Modo: DEFAULT');
        pkg_dm_enmascarar.proc_dm_enmascaramiento(
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
        select ora_esquema,
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
            -- FIX 2026-10-02: solo reactivaciones autenticas (lo que SI se
            -- deshabilito y luego SI se volvio a habilitar con exito), no el
            -- "ok trivial" que proc_dm_pre_dep marca para dependencias que ya
            -- no existian en el diccionario (ver comentario de declaracion).
            select count(*)
              into v_dep_enabled
              from tdm_mask_dep_estado
             where solicitud_id = v_solicitud_id
               and deshabilitado_ok = 'Y'
               and habilitado_ok = 'Y';
        exception when others then null;
        end;

        begin
            -- Dependencias configuradas en TDM_DEPENDENCIA_FINAL que no se
            -- encontraron en el diccionario al momento del PRE (constraint o
            -- trigger renombrado/eliminado desde el ultimo descubrimiento).
            -- No es un error del motor, pero si una señal de que la foto de
            -- dependencias esta desactualizada y conviene re-descubrir.
            select count(*)
              into v_dep_no_hallada
              from tdm_mask_dep_estado
             where solicitud_id = v_solicitud_id
               and deshabilitado_ok = 'N';
        exception when others then null;
        end;

        begin
            -- CRITICO: dependencias que SI se deshabilitaron pero que el POST
            -- no logro reactivar (quedaron deshabilitadas en el esquema real).
            -- Antes de este fix esto no era visible en el resumen: un fallo de
            -- reactivacion solo bajaba el v_dep_enabled "global", mezclado con
            -- las no-encontradas, sin ninguna señal explicita de alarma.
            select count(*)
              into v_dep_fallo_reactivar
              from tdm_mask_dep_estado
             where solicitud_id = v_solicitud_id
               and deshabilitado_ok = 'Y'
               and habilitado_ok = 'N';
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
    dbms_output.put_line('Dependencias (FK/UK/trigger) desactivadas: ' || v_dep_disabled);
    dbms_output.put_line('Dependencias reactivadas (desactivada=Y y reactivada=Y): ' || v_dep_enabled);
    if v_dep_no_hallada > 0 then
        dbms_output.put_line('Dependencias configuradas pero no halladas en el diccionario: ' || v_dep_no_hallada ||
                              ' (TDM_DEPENDENCIA_FINAL desactualizada -- revisar TDM_MASK_DEP_ESTADO, re-ejecutar descubrimiento)');
    end if;
    if v_dep_fallo_reactivar > 0 then
        dbms_output.put_line('*** ALERTA: dependencias desactivadas que NO se pudieron reactivar: ' || v_dep_fallo_reactivar ||
                              ' -- revisar TDM_MASK_DEP_ESTADO y TDM_EJECUCION_ERROR antes de dar por cerrada esta ejecucion ***');
    end if;
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
