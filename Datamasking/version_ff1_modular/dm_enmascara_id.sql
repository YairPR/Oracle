undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
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

Rem --- Esquema del motor: se detecta solo (ASTSYSADMIN o ACC_ADMIN), igual que dm_enmascara.sql ---
define esquemaast = '__NO_DETECTADO__'
column v_esquemaast noprint new_value esquemaast
select username as v_esquemaast
  from (select username from dba_users
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

prompt =========================================================
prompt dm_enmascara_id - Masking por identificador
prompt Uso:
prompt   @dm_enmascara_id EJECUCION_ID IDENTIFICADOR %
prompt   @dm_enmascara_id EJECUCION_ID IDENTIFICADOR Y
prompt Ejemplo:
prompt   @dm_enmascara_id 1 IDENTIFICADOR_BANCARIO %
prompt   @dm_enmascara_id 1 IDENTIFICADOR_BANCARIO Y
prompt Procesa SOLO las columnas aprobadas (enmascarar=Y) y las FORCE de ese identificador.
prompt No modifica el catalogo. El identificador queda en TDM_EJECUCION.MASK_IDENTIFICADOR mientras dura la corrida
prompt (la reanudacion lo reutiliza) y se vacia al terminar; el modo queda en TDM_MASK_SOLICITUD.alcance_tipo.
prompt =========================================================

set termout off
column "1" new_value 1 noprint
column "2" new_value 2 noprint
column "3" new_value 3 noprint
select null as "1", null as "2", null as "3" from dual where 1=2;

column final_p1 new_value V_ARG1 noprint
column final_p2 new_value V_ARG2 noprint
column final_p3 new_value V_ARG3 noprint

select trim('&1') final_p1,
       upper(trim('&2')) final_p2,
       upper(trim(nvl('&3', '%'))) final_p3
from dual;
set termout on

column c_ejecucion_id new_value V_EJEC_ID noprint
column c_solicitud_id new_value V_SOL_ID  noprint

declare
    v_tok1                  varchar2(4000) := trim('&&V_ARG1');
    v_identificador         varchar2(128)  := upper(trim('&&V_ARG2'));
    v_param                 varchar2(10)   := upper(trim('&&V_ARG3'));

    v_ejecucion_id          number;
    v_esquema               varchar2(128);
    v_sel_cols              number := 0;
    v_solicitud_id          number := -1;
    v_alc_tipo              varchar2(10);

    v_estado_pre            varchar2(30);
    v_estado_post           varchar2(30);
    v_fecha_ini_post        date;
    v_fecha_fin_post        date;
    v_ultimo_paso_post      varchar2(4000);
    v_ultimo_objeto_post    varchar2(4000);
    v_progreso_post         number;
begin
    if v_tok1 is null or not regexp_like(v_tok1, '^[0-9]+$') then
        raise_application_error(-20301,
            'Uso: @dm_enmascara_id EJECUCION_ID IDENTIFICADOR % | @dm_enmascara_id EJECUCION_ID IDENTIFICADOR Y');
    end if;
    v_ejecucion_id := to_number(v_tok1);

    if v_identificador is null then
        raise_application_error(-20302,
            'Debe indicar identificador. Ejemplo: IDENTIFICADOR_BANCARIO');
    end if;

    if v_param = '%' then
        v_param := 'N';
    end if;
    if v_param not in ('N','Y') then
        raise_application_error(-20303,
            'Parametro invalido. Usar % para default o Y para reproceso forzado.');
    end if;

    begin
        select ora_esquema, estado
          into v_esquema, v_estado_pre
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then
            raise_application_error(-20304,
                'No existe la ejecucion_id ' || v_ejecucion_id || ' en TDM_EJECUCION');
    end;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Ejecucion DM Enmascaramiento por ID');
    dbms_output.put_line('Ejecucion_id  : ' || v_ejecucion_id);
    dbms_output.put_line('Esquema       : ' || v_esquema);
    dbms_output.put_line('Identificador : ' || v_identificador);
    dbms_output.put_line('Parametro     : ' || case when v_param = 'Y' then 'Y' else '(default)' end);
    dbms_output.put_line('=========================================');

    -- La seleccion la valida y la guarda el paquete (rechaza solicitud en curso y seleccion vacia).
    pkg_dm_enmascarar.proc_dm_registra_alcance_id(v_ejecucion_id, v_identificador, v_sel_cols);
    dbms_output.put_line('Columnas seleccionadas para el identificador: ' || v_sel_cols || ' (catalogo no modificado).');

    if upper(nvl(v_estado_pre,'?')) = 'ERROR' then
        dbms_output.put_line('ADVERTENCIA: la ejecucion venia previamente en estado ERROR.');
        dbms_output.put_line('-----------------------------------------');
    end if;

    if v_param = 'Y' then
        dbms_output.put_line('Modo: FORZAR / REPROCESO');
    else
        dbms_output.put_line('Modo: DEFAULT');
    end if;
    pkg_dm_enmascarar.proc_dm_enmascaramiento(
        p_ejecucion_id => v_ejecucion_id,
        p_reproceso    => v_param,
        p_commit_lote  => 1000
    );

    begin
        select nvl(max(s.solicitud_id), -1) into v_solicitud_id
          from tdm_mask_solicitud s where s.ejecucion_id = v_ejecucion_id;
    exception
        when others then v_solicitud_id := -1;
    end;

    begin
        select alcance_tipo into v_alc_tipo
          from tdm_mask_solicitud where solicitud_id = v_solicitud_id;
    exception
        when others then null;
    end;

    begin
        select estado, cast(fecha_inicio as date), cast(fecha_fin as date),
               ultimo_paso, ultimo_objeto, progreso_pct
          into v_estado_post, v_fecha_ini_post, v_fecha_fin_post,
               v_ultimo_paso_post, v_ultimo_objeto_post, v_progreso_post
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then v_estado_post := null;
    end;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen final');
    dbms_output.put_line('Esquema                : ' || v_esquema);
    dbms_output.put_line('Identificador          : ' || v_identificador);
    if v_alc_tipo is not null then
        dbms_output.put_line('Alcance                : ' || v_alc_tipo);
    end if;
    dbms_output.put_line('Solicitud_id           : ' || case when v_solicitud_id = -1 then '(no encontrada)' else to_char(v_solicitud_id) end);
    dbms_output.put_line('Columnas seleccionadas : ' || v_sel_cols);
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
    if upper(nvl(v_estado_post,'?')) = 'ERROR' then
        dbms_output.put_line('ADVERTENCIA FINAL      : La ejecucion quedo en ERROR. Revisar trazas y errores.');
    end if;
    dbms_output.put_line('=========================================');
end;
/

select &&V_ARG1 as c_ejecucion_id from dual;

select nvl(max(s.solicitud_id), -1) as c_solicitud_id
from tdm_mask_solicitud s
where s.ejecucion_id = &V_EJEC_ID;

prompt
prompt =========================================================
prompt 1. COLUMNAS ENMASCARADAS EN ESTA SOLICITUD (APPLY_COL de la traza)
prompt =========================================================

select substr(t.detalle, 1, instr(t.detalle, ' filas=') - 1) as c_objeto,
       to_char(t.fecha_evento,'dd-mm-yyyy hh24:mi:ss') as c_fecha
from tdm_mask_trace t
where t.solicitud_id = &V_SOL_ID
  and &V_SOL_ID <> -1
  and t.fase = 'MASK'
  and t.paso = 'APPLY_COL'
  and instr(t.detalle, ' filas=') > 0
order by t.trace_id;

prompt
prompt =========================================================
prompt 2. SOLICITUD DE MASKING
prompt =========================================================

select s.solicitud_id,
       s.ejecucion_id,
       s.estado,
       s.forzar_reproceso,
       s.alcance_tipo,
       s.filas_procesadas,
       to_char(s.fecha_inicio,'dd-mm-yyyy hh24:mi:ss') as fecha_inicio,
       case when s.fecha_fin is not null
            then to_char(s.fecha_fin,'dd-mm-yyyy hh24:mi:ss')
       end as fecha_fin
from tdm_mask_solicitud s
where s.solicitud_id = &V_SOL_ID;

prompt
prompt =========================================================
prompt 3. TRAZABILIDAD DETALLADA DE LA EJECUCION
prompt =========================================================

select *
from (
    select t.trace_id                    as c_trace_id,
           t.solicitud_id,
           t.nivel                       as c_nivel,
           t.fase                        as c_fase,
           t.paso                        as c_paso,
           substr(t.detalle,1,100)       as c_detalle,
           to_char(t.fecha_evento,'dd-mm-yyyy hh24:mi:ss') as c_fecha
    from tdm_mask_trace t
    where t.ejecucion_id = &V_EJEC_ID
    order by t.solicitud_id desc, t.fecha_evento, t.trace_id
)
where rownum <= 200;

prompt
prompt =========================================================
prompt 4. RESUMEN DE DEPENDENCIAS PRE/POST
prompt =========================================================

select d.tipo_objeto                  as c_tipo_objeto,
       count(*)                       as c_total,
       sum(case when d.deshabilitado_ok = 'Y' then 1 else 0 end) as deshabilitado_ok,
       sum(case when d.habilitado_ok   = 'Y' then 1 else 0 end) as habilitado_ok
from tdm_mask_dep_estado d
where d.solicitud_id = &V_SOL_ID
  and &V_SOL_ID <> -1
group by d.tipo_objeto
order by d.tipo_objeto;

prompt
prompt =========================================================
prompt FIN dm_enmascara_id
prompt =========================================================

undefine 1
undefine 2
undefine 3
undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
undefine V_EJEC_ID
undefine V_SOL_ID
